`timescale 1ns/1ps

// =============================================================================
// m04_scoreboard : scoreboard task 분리
//
// m03_fork 대비 변화:
//   - recv_and_check를 recv_byte(monitor)와 uart_scoreboard로 분리한다.
//   - monitor는 수신만, scoreboard는 비교만 담당한다.
//   - actual 전달은 공유 변수와 event로 직접 연결한다.
//
// 한계(이 단계는 이해를 위한 코드이며 최종 구현 방식이 아님):
//   - 공유 변수가 하나라서 monitor가 다음 바이트를 쓰기 전에
//     scoreboard가 읽어야 한다. 타이밍 의존성과 덮어쓰기 위험이 있다.
//     → 공유 변수 대신 queue가 필요한 이유.
//   - scoreboard가 payload를 직접 참조해서 expected를 만든다.
//     scoreboard는 비교만 해야 하며 expected는 sequence가 분배해야 한다.
//     → sequence가 driver/expected 경로로 데이터를 분배해야 하는 이유.
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
    // monitor → scoreboard 공유 변수 + event
    // -------------------------------------------------------------------------
    logic [7:0] r_MonData;
    event       e_MonDataReady;

    int r_PassCnt = 0;
    int r_FailCnt = 0;

    // -------------------------------------------------------------------------
    // 테스트 payload
    // -------------------------------------------------------------------------
    logic [7:0] r_Payload [0:PAYLOAD_SIZE-1];

    // -------------------------------------------------------------------------
    // task: send_byte(driver)
    // -------------------------------------------------------------------------
    task send_byte(input logic [7:0] data);
        // CPU 출력 레지스터처럼 상승 엣지에서 요청을 등록한다.
        // DUT는 다음 상승 엣지에서 valid/data를 샘플링한다.
        do @(posedge r_Clk); while (!w_TxReady);
        r_TxData  <= data;
        r_TxValid <= 1'b1;
        @(posedge r_Clk);
        r_TxValid <= 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // task: recv_byte(monitor)
    // 수신만 담당하고 공유 변수에 쓴 뒤 event를 발생시킨다.
    // -------------------------------------------------------------------------
    task recv_byte();
        logic [7:0] captured;

        @(negedge w_TxSerial);
        repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge r_Clk);
        for (int r_BitIdx = 0; r_BitIdx < 8; r_BitIdx++) begin
            captured[r_BitIdx] = w_TxSerial;
            if (r_BitIdx < 7)
                repeat (CLKS_PER_BIT) @(posedge r_Clk);
        end

        r_MonData = captured;
        -> e_MonDataReady;
    endtask

    // -------------------------------------------------------------------------
    // task: uart_scoreboard
    // 비교만 담당하며 event로 깨어나 공유 변수를 읽는다.
    // 주의: expected를 payload에서 직접 만드는 것은 올바른 최종 구조가 아니다.
    // -------------------------------------------------------------------------
    task uart_scoreboard(input int num_bytes);
        logic [7:0] r_ExpectedQ [$];
        logic [7:0] r_Actual;
        logic [7:0] r_Expected;

        foreach (r_Payload[r_ByteIdx])
            r_ExpectedQ.push_back(r_Payload[r_ByteIdx]);

        repeat (num_bytes) begin
            @(e_MonDataReady);
            r_Actual   = r_MonData;
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
        r_MonData = '0;
        repeat (5) @(posedge r_Clk);
        r_Rsn = 1'b1;
        @(posedge r_Clk);

        fork
            begin : DRIVER_THREAD
                foreach (r_Payload[r_ByteIdx])
                    send_byte(r_Payload[r_ByteIdx]);
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
