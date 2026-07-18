`timescale 1ns/1ps

// =============================================================================
// m07_expected_path : expected ownership 분리
//
// m06_sequence 대비 변화:
//   - sequence가 payload를 관리하고 driver/expected queue를 함께 채운다.
//   - driver는 driver queue에서 stimulus를 꺼내 DUT를 구동한다.
//   - scoreboard는 payload를 직접 읽지 않고 expected/actual queue만 비교한다.
//
// 핵심:
//   - stimulus ownership과 expected ownership이 모두 sequence 쪽으로 이동한다.
//   - scoreboard는 실제로 비교와 결과 집계만 담당한다.
// =============================================================================

module TB_Top;

    localparam int CLK_FREQ     = 50_000_000;
    localparam int BAUD_RATE    = 115_200;
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam int PAYLOAD_SIZE = 5;

    // -------------------------------------------------------------------------
    // 클럭 및 리셋
    // -------------------------------------------------------------------------
    logic r_Clk = 1'b0;
    logic r_Rsn;

    always #10 r_Clk = ~r_Clk;   // 50 MHz

    // -------------------------------------------------------------------------
    // DUT 연결 신호
    // -------------------------------------------------------------------------
    logic [7:0] r_TxData;
    logic       r_TxValid;
    logic       w_TxReady;
    logic       w_TxSerial;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    UART_Tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) I_UART_Tx (
        .i_Clk      (r_Clk),
        .i_Rsn      (r_Rsn),
        .i_TxData   (r_TxData),
        .i_TxValid  (r_TxValid),
        .o_TxReady  (w_TxReady),
        .o_TxSerial (w_TxSerial)
    );

    // -------------------------------------------------------------------------
    // sequence → driver/scoreboard, monitor → scoreboard queue
    // -------------------------------------------------------------------------
    logic [7:0] r_DrvQ [$];
    logic [7:0] r_ExpQ [$];
    logic [7:0] r_MonQ [$];
    event       e_MonDataReady;

    int r_PassCnt = 0;
    int r_FailCnt = 0;

    // -------------------------------------------------------------------------
    // 테스트 payload
    // -------------------------------------------------------------------------
    logic [7:0] r_Payload [0:PAYLOAD_SIZE-1];

    // -------------------------------------------------------------------------
    // task: uart_sequence
    // 같은 payload를 stimulus와 expected 경로에 함께 분배한다.
    // -------------------------------------------------------------------------
    task uart_sequence();
        foreach (r_Payload[r_ByteIdx]) begin
            r_DrvQ.push_back(r_Payload[r_ByteIdx]);
            r_ExpQ.push_back(r_Payload[r_ByteIdx]);
            $display("[SEQ] queued stimulus/expected: 0x%02h", r_Payload[r_ByteIdx]);
        end
    endtask

    // -------------------------------------------------------------------------
    // task: uart_driver
    // driver queue에서 꺼낸 data로 DUT를 구동한다.
    // -------------------------------------------------------------------------
    task uart_driver(input int num_bytes);
        logic [7:0] r_Data;

        repeat (num_bytes) begin
            r_Data = r_DrvQ.pop_front();
            $display("[DRV] driving: 0x%02h", r_Data);

            // CPU 출력 레지스터처럼 상승 엣지에서 요청을 등록한다.
            // DUT는 다음 상승 엣지에서 valid/data를 샘플링한다.
            do @(posedge r_Clk); while (!w_TxReady);
            r_TxData  <= r_Data;
            r_TxValid <= 1'b1;
            @(posedge r_Clk);
            r_TxValid <= 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // task: recv_byte(monitor)
    // 수신 바이트를 actual queue에 넣은 뒤 event를 발생시킨다.
    // -------------------------------------------------------------------------
    task recv_byte();
        logic [7:0] r_Captured;

        @(negedge w_TxSerial);
        repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge r_Clk);
        for (int r_BitIdx = 0; r_BitIdx < 8; r_BitIdx++) begin
            r_Captured[r_BitIdx] = w_TxSerial;
            if (r_BitIdx < 7)
                repeat (CLKS_PER_BIT) @(posedge r_Clk);
        end

        r_MonQ.push_back(r_Captured);
        -> e_MonDataReady;
    endtask

    // -------------------------------------------------------------------------
    // task: uart_scoreboard
    // actual queue와 expected queue에서 각각 꺼내 비교한다.
    // -------------------------------------------------------------------------
    task uart_scoreboard(input int num_bytes);
        logic [7:0] r_Actual;
        logic [7:0] r_Expected;

        repeat (num_bytes) begin
            @(e_MonDataReady);
            r_Actual   = r_MonQ.pop_front();
            r_Expected = r_ExpQ.pop_front();

            if (r_Actual === r_Expected) begin
                $display("[SB] PASS: expected=0x%02h actual=0x%02h", r_Expected, r_Actual);
                r_PassCnt++;
            end else begin
                $display("[SB] FAIL: expected=0x%02h actual=0x%02h", r_Expected, r_Actual);
                r_FailCnt++;
            end
        end
    endtask

    initial begin
        r_Payload[0] = 8'h48;  // 'H'
        r_Payload[1] = 8'h65;  // 'e'
        r_Payload[2] = 8'h6c;  // 'l'
        r_Payload[3] = 8'h6c;  // 'l'
        r_Payload[4] = 8'h6f;  // 'o'
    end

    initial begin
        r_Rsn     = 1'b0;
        r_TxValid = 1'b0;
        r_TxData  = '0;
        repeat (5) @(posedge r_Clk);
        r_Rsn = 1'b1;
        @(posedge r_Clk);

        uart_sequence();

        fork
            begin : DRIVER_THREAD
                uart_driver(PAYLOAD_SIZE);
            end
            begin : MONITOR_THREAD
                repeat (PAYLOAD_SIZE)
                    recv_byte();
            end
            begin : SCOREBOARD_THREAD
                uart_scoreboard(PAYLOAD_SIZE);
            end
        join

        $display("[SB] ===== REPORT =====");
        $display("[SB] RESULT: pass=%0d fail=%0d", r_PassCnt, r_FailCnt);
        if (r_PassCnt == PAYLOAD_SIZE && r_FailCnt == 0) begin
            $display("[SB] ALL TESTS PASSED");
        end else begin
            $fatal(1, "[SB] TEST FAILED: pass=%0d fail=%0d", r_PassCnt, r_FailCnt);
        end

        repeat (5 * CLKS_PER_BIT) @(posedge r_Clk);
        $finish;
    end

endmodule
