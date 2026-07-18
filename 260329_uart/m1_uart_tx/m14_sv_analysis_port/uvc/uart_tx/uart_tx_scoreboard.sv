// UART TX scoreboard class.
//
// expected item은 m13처럼 sequence mailbox에서 받고, actual item은 analysis_imp가
// 호출하는 write() callback에서 비교한다.

class uart_tx_scoreboard;
    mailbox #(uart_tx_seq_item) exp_mbx;
    uart_tx_seq_item expected_q[$];
    int pass_cnt   = 0;
    int fail_cnt   = 0;
    int actual_cnt = 0;
    int target_cnt = 0;

    function new(mailbox #(uart_tx_seq_item) exp_mbx);
        this.exp_mbx = exp_mbx;
    endfunction

    task reset(input int num_expected);
        uart_tx_seq_item ignored;

        while (exp_mbx.try_get(ignored)) begin
        end
        expected_q.delete();
        pass_cnt   = 0;
        fail_cnt   = 0;
        actual_cnt = 0;
        target_cnt = num_expected;
    endtask

    task run_expected(input int num_expected);
        uart_tx_seq_item expected;

        repeat (num_expected) begin
            exp_mbx.get(expected);
            expected_q.push_back(expected);
            $display("[SB] expected queued: 0x%02h", expected.data);
        end
    endtask

    function void write(input uart_tx_seq_item actual);
        uart_tx_seq_item expected;

        actual_cnt++;

        if (expected_q.size() == 0) begin
            $display("[SB] FAIL: unexpected actual=0x%02h", actual.data);
            fail_cnt++;
        end else begin
            expected = expected_q.pop_front();

            if (actual.data === expected.data) begin
                $display("[SB] PASS: expected=0x%02h actual=0x%02h", expected.data, actual.data);
                pass_cnt++;
            end else begin
                $display("[SB] FAIL: expected=0x%02h actual=0x%02h", expected.data, actual.data);
                fail_cnt++;
            end
        end
    endfunction

    task report();
        if (actual_cnt != target_cnt) begin
            $display("[SB] FAIL: expected %0d actual items, got %0d", target_cnt, actual_cnt);
            fail_cnt++;
        end
        if (expected_q.size() != 0) begin
            $display("[SB] FAIL: %0d expected items were not compared", expected_q.size());
            fail_cnt++;
        end

        $display("[SB] ===== REPORT =====");
        $display("[SB] RESULT: pass=%0d fail=%0d", pass_cnt, fail_cnt);
        if (pass_cnt == target_cnt && fail_cnt == 0) begin
            $display("[SB] ALL TESTS PASSED");
        end else begin
            $fatal(1, "[SB] TEST FAILED: pass=%0d fail=%0d", pass_cnt, fail_cnt);
        end
    endtask
endclass
