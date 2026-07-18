`timescale 1ns/1ps

// =============================================================================
// m08_role_split : task 수준 역할 계층
//
// m07_expected_path 대비 변화:
//   - uart_tx_agent()가 driver와 monitor를 함께 관리한다.
//   - uart_tx_env()가 agent와 scoreboard를 함께 관리한다.
//   - uart_tx_test()가 payload 준비, sequence 실행, env 기동을 맡는다.
//
// 핵심:
//   - stimulus/expected/actual 데이터 경로는 m07 구조를 유지한다.
//   - UVM에서 사용하는 test/env/agent 역할 경계를 task로 먼저 드러낸다.
//   - 아직 class 기반 UVM은 아니며 task 기반의 중간 단계다.
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
    // 역할 사이 데이터 handoff
    // -------------------------------------------------------------------------
    logic [7:0] r_DrvQ [$];
    logic [7:0] r_ExpQ [$];
    logic [7:0] r_MonQ [$];
    event       e_MonDataReady;

    logic [7:0] r_Payload [0:PAYLOAD_SIZE-1];

    int r_PassCnt = 0;
    int r_FailCnt = 0;

    // -------------------------------------------------------------------------
    // sequence: 같은 payload를 stimulus와 expected 경로에 함께 적재한다.
    // -------------------------------------------------------------------------
    task uart_tx_sequence();
        foreach (r_Payload[r_ByteIdx]) begin
            r_DrvQ.push_back(r_Payload[r_ByteIdx]);
            r_ExpQ.push_back(r_Payload[r_ByteIdx]);
            $display("[SEQ] queued stimulus/expected: 0x%02h", r_Payload[r_ByteIdx]);
        end
    endtask

    // -------------------------------------------------------------------------
    // driver: driver queue에서 꺼낸 byte만 DUT에 구동한다.
    // -------------------------------------------------------------------------
    task uart_tx_driver(input int num_bytes);
        logic [7:0] r_Data;

        repeat (num_bytes) begin
            r_Data = r_DrvQ.pop_front();
            $display("[DRV] driving: 0x%02h", r_Data);

            // CPU 출력 레지스터처럼 상승 에지에서 요청을 등록한다.
            // DUT는 다음 상승 에지에서 valid/data를 샘플링한다.
            do @(posedge r_Clk); while (!w_TxReady);
            r_TxData  <= r_Data;
            r_TxValid <= 1'b1;
            @(posedge r_Clk);
            r_TxValid <= 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // monitor: 직렬 출력을 byte로 복원하고 actual queue에 전달한다.
    // -------------------------------------------------------------------------
    task uart_tx_monitor(input int num_bytes);
        logic [7:0] r_Captured;

        repeat (num_bytes) begin
            @(negedge w_TxSerial);
            repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge r_Clk);
            for (int r_BitIdx = 0; r_BitIdx < 8; r_BitIdx++) begin
                r_Captured[r_BitIdx] = w_TxSerial;
                if (r_BitIdx < 7)
                    repeat (CLKS_PER_BIT) @(posedge r_Clk);
            end

            r_MonQ.push_back(r_Captured);
            -> e_MonDataReady;
        end
    endtask

    // -------------------------------------------------------------------------
    // scoreboard: expected와 actual queue만 비교한다.
    // -------------------------------------------------------------------------
    task uart_tx_scoreboard(input int num_bytes);
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

    // -------------------------------------------------------------------------
    // agent: 한 UART interface의 driver와 monitor 역할을 묶는다.
    // -------------------------------------------------------------------------
    task uart_tx_agent(input int num_bytes);
        fork
            begin : DRIVER_THREAD
                uart_tx_driver(num_bytes);
            end
            begin : MONITOR_THREAD
                uart_tx_monitor(num_bytes);
            end
        join
    endtask

    // -------------------------------------------------------------------------
    // env: agent와 scoreboard를 병렬로 실행한다.
    // -------------------------------------------------------------------------
    task uart_tx_env(input int num_bytes);
        fork
            begin : AGENT_THREAD
                uart_tx_agent(num_bytes);
            end
            begin : SCOREBOARD_THREAD
                uart_tx_scoreboard(num_bytes);
            end
        join
    endtask

    // -------------------------------------------------------------------------
    // test: payload 준비, sequence 실행, env 기동과 최종 판정을 맡는다.
    // -------------------------------------------------------------------------
    task uart_tx_test();
        r_Payload[0] = 8'h48;  // 'H'
        r_Payload[1] = 8'h65;  // 'e'
        r_Payload[2] = 8'h6c;  // 'l'
        r_Payload[3] = 8'h6c;  // 'l'
        r_Payload[4] = 8'h6f;  // 'o'

        $display("[TEST] ROLE_SPLIT_START bytes=%0d", PAYLOAD_SIZE);

        uart_tx_sequence();
        uart_tx_env(PAYLOAD_SIZE);

        $display("[SB] ===== REPORT =====");
        $display("[SB] RESULT: pass=%0d fail=%0d", r_PassCnt, r_FailCnt);
        if (r_PassCnt == PAYLOAD_SIZE && r_FailCnt == 0) begin
            $display("[SB] ALL TESTS PASSED");
        end else begin
            $fatal(1, "[SB] TEST FAILED: pass=%0d fail=%0d", r_PassCnt, r_FailCnt);
        end

        $display("[TEST] ROLE_SPLIT_DONE");
    endtask

    initial begin
        r_Rsn     = 1'b0;
        r_TxValid = 1'b0;
        r_TxData  = '0;
        repeat (5) @(posedge r_Clk);
        r_Rsn = 1'b1;
        @(posedge r_Clk);

        uart_tx_test();

        repeat (5 * CLKS_PER_BIT) @(posedge r_Clk);
        $finish;
    end

endmodule
