// TB_Top scope에 include되는 scoreboard 역할 파일.
// expected와 actual sequence item mailbox를 blocking get으로 맞춰 비교한다.

mailbox #(uart_tx_seq_item) r_ExpMbx = new();
mailbox #(uart_tx_seq_item) r_MonMbx = new();
int                        r_PassCnt = 0;
int                        r_FailCnt = 0;

task automatic uart_tx_scoreboard_reset();
    uart_tx_seq_item ignored;

    while (r_ExpMbx.try_get(ignored)) begin
    end
    while (r_MonMbx.try_get(ignored)) begin
    end

    r_PassCnt = 0;
    r_FailCnt = 0;
endtask

task automatic uart_tx_scoreboard_put_expected(input uart_tx_seq_item item);
    r_ExpMbx.put(item);
endtask

task automatic uart_tx_scoreboard_write_actual(input uart_tx_seq_item item);
    r_MonMbx.put(item);
endtask

task automatic uart_tx_scoreboard_run(input int num_bytes);
    uart_tx_seq_item actual;
    uart_tx_seq_item expected;

    repeat (num_bytes) begin
        r_ExpMbx.get(expected);
        r_MonMbx.get(actual);

        if (actual.data === expected.data) begin
            $display("[SB] PASS: expected=0x%02h actual=0x%02h", expected.data, actual.data);
            r_PassCnt++;
        end else begin
            $display("[SB] FAIL: expected=0x%02h actual=0x%02h", expected.data, actual.data);
            r_FailCnt++;
        end
    end
endtask

task automatic uart_tx_scoreboard_report();
    $display("[SB] ===== REPORT =====");
    $display("[SB] RESULT: pass=%0d fail=%0d", r_PassCnt, r_FailCnt);
    if (r_PassCnt == UART_TX_NUM_BYTES && r_FailCnt == 0) begin
        $display("[SB] ALL TESTS PASSED");
    end else begin
        $fatal(1, "[SB] TEST FAILED: pass=%0d fail=%0d", r_PassCnt, r_FailCnt);
    end
endtask
