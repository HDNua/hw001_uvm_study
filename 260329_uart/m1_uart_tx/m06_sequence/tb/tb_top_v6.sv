`timescale 1ns/1ps

// =============================================================================
// m06_sequence : stimulus 생성을 sequence 역할로 분리
//
// m05_queue 대비 변화:
//   - sequence가 payload를 관리하고 driver queue에 적재한다.
//   - driver는 payload를 직접 읽지 않고 queue에서 꺼내 DUT를 구동한다.
//   - monitor와 scoreboard의 actual queue 경로는 m05와 동일하다.
//
// 한계(이 단계는 이해를 위한 코드이며 최종 구현 방식이 아님):
//   - scoreboard는 여전히 payload를 직접 참조해 expected queue를 만든다.
//   - stimulus ownership은 분리됐지만 expected ownership은 분리되지 않았다.
//     → sequence가 expected 경로에도 데이터를 분배해야 한다.
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
    // sequence → driver, monitor → scoreboard queue
    // -------------------------------------------------------------------------
    logic [7:0] r_DrvQ [$];
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
    // payload를 driver queue에 적재한다.
    // -------------------------------------------------------------------------
    task uart_sequence();
        foreach (r_Payload[r_ByteIdx]) begin
            r_DrvQ.push_back(r_Payload[r_ByteIdx]);
            $display("[SEQ] queued: 0x%02h", r_Payload[r_ByteIdx]);
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
    // actual queue에서 꺼낸 값과 payload에서 직접 만든 expected를 비교한다.
    // -------------------------------------------------------------------------
    task uart_scoreboard(input int num_bytes);
        logic [7:0] r_ExpectedQ [$];
        logic [7:0] r_Actual;
        logic [7:0] r_Expected;

        foreach (r_Payload[r_ByteIdx])
            r_ExpectedQ.push_back(r_Payload[r_ByteIdx]);

        repeat (num_bytes) begin
            @(e_MonDataReady);
            r_Actual   = r_MonQ.pop_front();
            r_Expected = r_ExpectedQ.pop_front();

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
