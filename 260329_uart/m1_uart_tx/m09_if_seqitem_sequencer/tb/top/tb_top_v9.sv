`timescale 1ns/1ps

// =============================================================================
// m09_if_seqitem_sequencer : interface / sequence item / sequencer 개념 도입
//
// m08_role_split 대비 변화:
//   - DUT pin 묶음을 uart_tx_if interface로 감싼다.
//   - payload byte를 uart_tx_seq_item object로 포장한다.
//   - sequence와 driver 사이에 sequencer 역할의 put/get task를 둔다.
//
// 핵심:
//   - driver / monitor / scoreboard / agent / env / test는 아직 task 기반이다.
//   - interface, sequence item, sequencer handoff를 class UVC 전에 드러낸다.
//   - stimulus/expected/actual의 ownership과 queue 경로는 m08을 유지한다.
// =============================================================================

module TB_Top;
    import uart_tx_pkg::*;

    localparam int PAYLOAD_SIZE = 5;

    // -------------------------------------------------------------------------
    // 클럭 및 리셋
    // -------------------------------------------------------------------------
    logic r_Clk = 1'b0;
    logic r_Rsn;

    always #10 r_Clk = ~r_Clk;   // 50 MHz

    // -------------------------------------------------------------------------
    // UART TX interface와 DUT
    // -------------------------------------------------------------------------
    uart_tx_if I_UART_TxIf (
        .i_Clk (r_Clk),
        .i_Rsn (r_Rsn)
    );

    UART_Tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) I_UART_Tx (
        .i_Clk      (I_UART_TxIf.i_Clk),
        .i_Rsn      (I_UART_TxIf.i_Rsn),
        .i_TxData   (I_UART_TxIf.r_TxData),
        .i_TxValid  (I_UART_TxIf.r_TxValid),
        .o_TxReady  (I_UART_TxIf.w_TxReady),
        .o_TxSerial (I_UART_TxIf.w_TxSerial)
    );

    // -------------------------------------------------------------------------
    // 역할 사이 데이터 handoff
    // -------------------------------------------------------------------------
    uart_tx_seq_item r_SeqrQ [$];
    logic [7:0]      r_ExpQ  [$];
    logic [7:0]      r_MonQ  [$];
    event            e_MonDataReady;

    logic [7:0] r_Payload [0:PAYLOAD_SIZE-1];

    int r_PassCnt = 0;
    int r_FailCnt = 0;

    // -------------------------------------------------------------------------
    // sequencer API: sequence item queue를 put/get task로 감싼다.
    // -------------------------------------------------------------------------
    task uart_tx_sequencer_put_item(input uart_tx_seq_item item);
        r_SeqrQ.push_back(item);
        $display("[SEQR] put item: 0x%02h", item.data);
    endtask

    task uart_tx_sequencer_get_item(output uart_tx_seq_item item);
        while (r_SeqrQ.size() == 0)
            @(posedge r_Clk);

        item = r_SeqrQ.pop_front();
        $display("[SEQR] get item: 0x%02h", item.data);
    endtask

    // -------------------------------------------------------------------------
    // sequence: payload를 item으로 만들고 stimulus/expected에 함께 분배한다.
    // -------------------------------------------------------------------------
    task uart_tx_sequence();
        uart_tx_seq_item item;

        foreach (r_Payload[r_ByteIdx]) begin
            item = new(r_Payload[r_ByteIdx]);
            uart_tx_sequencer_put_item(item);
            r_ExpQ.push_back(item.data);
            $display("[SEQ] queued item/expected: 0x%02h", item.data);
        end
    endtask

    // -------------------------------------------------------------------------
    // driver: sequencer에서 받은 item으로 interface를 구동한다.
    // -------------------------------------------------------------------------
    task uart_tx_driver(input int num_bytes);
        uart_tx_seq_item item;

        repeat (num_bytes) begin
            uart_tx_sequencer_get_item(item);
            $display("[DRV] driving item: 0x%02h", item.data);

            do @(posedge r_Clk); while (!I_UART_TxIf.w_TxReady);
            I_UART_TxIf.r_TxData  <= item.data;
            I_UART_TxIf.r_TxValid <= 1'b1;
            @(posedge r_Clk);
            I_UART_TxIf.r_TxValid <= 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // monitor: 같은 interface에서 직렬 출력을 읽어 actual queue에 전달한다.
    // -------------------------------------------------------------------------
    task uart_tx_monitor(input int num_bytes);
        logic [7:0] r_Captured;

        repeat (num_bytes) begin
            @(negedge I_UART_TxIf.w_TxSerial);
            repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge r_Clk);
            for (int r_BitIdx = 0; r_BitIdx < 8; r_BitIdx++) begin
                r_Captured[r_BitIdx] = I_UART_TxIf.w_TxSerial;
                if (r_BitIdx < 7)
                    repeat (CLKS_PER_BIT) @(posedge r_Clk);
            end

            r_MonQ.push_back(r_Captured);
            -> e_MonDataReady;
            $display("[MON] captured item: 0x%02h", r_Captured);
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
    // agent: 한 UART TX interface의 driver와 monitor를 묶는다.
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
    // test: payload 준비와 sequence/env 병렬 기동 및 최종 판정을 맡는다.
    // -------------------------------------------------------------------------
    task uart_tx_test();
        r_Payload[0] = 8'h48;  // 'H'
        r_Payload[1] = 8'h65;  // 'e'
        r_Payload[2] = 8'h6c;  // 'l'
        r_Payload[3] = 8'h6c;  // 'l'
        r_Payload[4] = 8'h6f;  // 'o'

        $display("[TEST] IF_SEQITEM_SEQUENCER_START bytes=%0d", PAYLOAD_SIZE);

        fork
            begin : SEQUENCE_THREAD
                uart_tx_sequence();
            end
            begin : ENV_THREAD
                uart_tx_env(PAYLOAD_SIZE);
            end
        join

        $display("[SB] ===== REPORT =====");
        $display("[SB] RESULT: pass=%0d fail=%0d", r_PassCnt, r_FailCnt);
        if (r_PassCnt == PAYLOAD_SIZE && r_FailCnt == 0) begin
            $display("[SB] ALL TESTS PASSED");
        end else begin
            $fatal(1, "[SB] TEST FAILED: pass=%0d fail=%0d", r_PassCnt, r_FailCnt);
        end

        $display("[TEST] IF_SEQITEM_SEQUENCER_DONE");
    endtask

    initial begin
        r_Rsn                   = 1'b0;
        I_UART_TxIf.r_TxData  = '0;
        I_UART_TxIf.r_TxValid = 1'b0;

        repeat (5) @(posedge r_Clk);
        r_Rsn = 1'b1;
        @(posedge r_Clk);

        uart_tx_test();

        repeat (5 * CLKS_PER_BIT) @(posedge r_Clk);
        $finish;
    end

endmodule
