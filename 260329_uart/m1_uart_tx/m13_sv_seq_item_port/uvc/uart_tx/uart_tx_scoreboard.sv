// UART TX scoreboard class.
//
// m12의 expected/actual mailbox와 비교 동작을 그대로 유지한다.

class uart_tx_scoreboard;
    mailbox #(uart_tx_seq_item) exp_mbx;
    mailbox #(uart_tx_seq_item) mon_mbx;
    int pass_cnt = 0;
    int fail_cnt = 0;

    function new(
        mailbox #(uart_tx_seq_item) exp_mbx,
        mailbox #(uart_tx_seq_item) mon_mbx
    );
        this.exp_mbx = exp_mbx;
        this.mon_mbx = mon_mbx;
    endfunction

    task reset();
        uart_tx_seq_item ignored;

        while (exp_mbx.try_get(ignored)) begin
        end
        while (mon_mbx.try_get(ignored)) begin
        end

        pass_cnt = 0;
        fail_cnt = 0;
    endtask

    task run(input int num_bytes);
        uart_tx_seq_item actual;
        uart_tx_seq_item expected;

        repeat (num_bytes) begin
            exp_mbx.get(expected);
            mon_mbx.get(actual);

            if (actual.data === expected.data) begin
                $display("[SB] PASS: expected=0x%02h actual=0x%02h", expected.data, actual.data);
                pass_cnt++;
            end else begin
                $display("[SB] FAIL: expected=0x%02h actual=0x%02h", expected.data, actual.data);
                fail_cnt++;
            end
        end
    endtask

    task report();
        $display("[SB] ===== REPORT =====");
        $display("[SB] RESULT: pass=%0d fail=%0d", pass_cnt, fail_cnt);
        if (pass_cnt == UART_TX_NUM_BYTES && fail_cnt == 0) begin
            $display("[SB] ALL TESTS PASSED");
        end else begin
            $fatal(1, "[SB] TEST FAILED: pass=%0d fail=%0d", pass_cnt, fail_cnt);
        end
    endtask
endclass
