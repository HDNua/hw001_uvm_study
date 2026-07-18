// TB_Top scope에 include되는 scoreboard 역할 파일.
// expected queue와 actual queue의 비교 및 case별 결과 집계를 담당한다.

logic [7:0] r_ExpQ [$];
logic [7:0] r_MonQ [$];
event       e_MonDataReady;
int         r_PassCnt = 0;
int         r_FailCnt = 0;

task automatic uart_tx_scoreboard_reset();
    r_ExpQ.delete();
    r_MonQ.delete();
    r_PassCnt = 0;
    r_FailCnt = 0;
endtask

task automatic uart_tx_scoreboard_push_expected(input logic [7:0] data);
    r_ExpQ.push_back(data);
endtask

task automatic uart_tx_scoreboard_write_actual(input logic [7:0] data);
    r_MonQ.push_back(data);
    -> e_MonDataReady;
endtask

task automatic uart_tx_scoreboard_run(input int num_bytes);
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

task automatic uart_tx_scoreboard_report();
    $display("[SB] ===== REPORT =====");
    $display("[SB] RESULT: pass=%0d fail=%0d", r_PassCnt, r_FailCnt);
    if (r_PassCnt == UART_TX_NUM_BYTES && r_FailCnt == 0) begin
        $display("[SB] ALL TESTS PASSED");
    end else begin
        $fatal(1, "[SB] TEST FAILED: pass=%0d fail=%0d", r_PassCnt, r_FailCnt);
    end
endtask
