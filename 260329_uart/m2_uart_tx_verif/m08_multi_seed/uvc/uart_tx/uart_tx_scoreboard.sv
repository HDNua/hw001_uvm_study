// expected와 actual을 서로 다른 실제 UVM analysis imp로 받는다.
`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

class uart_tx_scoreboard extends uvm_scoreboard;
    uvm_analysis_imp_expected #(uart_tx_seq_item, uart_tx_scoreboard) expected_imp;
    uvm_analysis_imp_actual #(uart_tx_seq_item, uart_tx_scoreboard) actual_imp;

    uart_tx_seq_item expected_q[$];
    int pass_cnt   = 0;
    int fail_cnt   = 0;
    int actual_cnt = 0;
    int target_cnt = 0;
    event done_e;

    `uvm_component_utils(uart_tx_scoreboard)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        expected_imp = new("expected_imp", this);
        actual_imp   = new("actual_imp", this);
    endfunction

    function void reset_case(input int num_expected);
        expected_q.delete();
        pass_cnt   = 0;
        fail_cnt   = 0;
        actual_cnt = 0;
        target_cnt = num_expected;
    endfunction

    // 전송 중 리셋: 잘린 프레임의 in-flight expected는 actual이 오지
    // 않으므로 목표에서 제외한다.
    function void on_reset();
        int unsigned dropped;

        dropped = expected_q.size();
        expected_q.delete();
        target_cnt -= dropped;
        `uvm_info("SB", $sformatf("reset: dropped %0d in-flight expected", dropped), UVM_LOW)
    endfunction

    function void write_expected(input uart_tx_seq_item expected);
        expected_q.push_back(expected);
        `uvm_info("SB", $sformatf("expected item: 0x%02h", expected.data), UVM_LOW)
    endfunction

    function void write_actual(input uart_tx_seq_item actual);
        uart_tx_seq_item expected;

        actual_cnt++;
        if (expected_q.size() == 0) begin
            `uvm_error("SB", $sformatf("unexpected actual item: 0x%02h", actual.data))
            fail_cnt++;
        end else begin
            expected = expected_q.pop_front();
            if (actual.data === expected.data) begin
                `uvm_info("SB", $sformatf("PASS: expected=0x%02h actual=0x%02h", expected.data, actual.data), UVM_LOW)
                pass_cnt++;
            end else begin
                `uvm_error("SB", $sformatf("FAIL: expected=0x%02h actual=0x%02h", expected.data, actual.data))
                fail_cnt++;
            end
        end

        if (actual_cnt >= target_cnt)
            ->done_e;
    endfunction

    task wait_done();
        if (actual_cnt < target_cnt)
            @(done_e);
    endtask

    function void report_case();
        if (actual_cnt != target_cnt) begin
            `uvm_error("SB", $sformatf("expected %0d actual items, got %0d", target_cnt, actual_cnt))
            fail_cnt++;
        end
        if (expected_q.size() != 0) begin
            `uvm_error("SB", $sformatf("%0d expected items were not compared", expected_q.size()))
            fail_cnt++;
        end

        `uvm_info("SB", "===== REPORT =====", UVM_LOW)
        `uvm_info("SB", $sformatf("RESULT: pass=%0d fail=%0d", pass_cnt, fail_cnt), UVM_LOW)
        if (pass_cnt == target_cnt && fail_cnt == 0)
            `uvm_info("SB", "ALL TESTS PASSED", UVM_LOW)
        else
            `uvm_error("SB", $sformatf("TEST FAILED: pass=%0d fail=%0d", pass_cnt, fail_cnt))
    endfunction
endclass
