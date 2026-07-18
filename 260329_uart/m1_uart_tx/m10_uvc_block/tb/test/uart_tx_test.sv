// TB_Top scope에 include되는 단계 전용 test 역할 파일.
// smoke, pattern과 random payload를 같은 UART TX UVC에서 순차 실행한다.

localparam int UART_TX_SEQ_SMOKE   = 0;
localparam int UART_TX_SEQ_PATTERN = 1;
localparam int UART_TX_SEQ_RANDOM  = 2;

task automatic uart_tx_load_smoke_payload();
    r_Payload[0] = 8'h48;  // 'H'
    r_Payload[1] = 8'h65;  // 'e'
    r_Payload[2] = 8'h6c;  // 'l'
    r_Payload[3] = 8'h6c;  // 'l'
    r_Payload[4] = 8'h6f;  // 'o'
endtask

task automatic uart_tx_load_pattern_payload();
    r_Payload[0] = 8'h00;
    r_Payload[1] = 8'hff;
    r_Payload[2] = 8'h55;
    r_Payload[3] = 8'haa;
    r_Payload[4] = 8'h3c;
endtask

task automatic uart_tx_load_random_payload();
    foreach (r_Payload[r_ByteIdx])
        r_Payload[r_ByteIdx] = $urandom_range(8'h00, 8'hff);
endtask

task automatic uart_tx_print_payload();
    $write("[TEST] Payload bytes:");
    foreach (r_Payload[r_ByteIdx])
        $write(" %02h", r_Payload[r_ByteIdx]);
    $write("\n");
endtask

task automatic uart_tx_run_selected_sequence(input int seq_kind);
    case (seq_kind)
        UART_TX_SEQ_SMOKE:   uart_tx_smoke_sequence();
        UART_TX_SEQ_PATTERN: uart_tx_pattern_sequence();
        UART_TX_SEQ_RANDOM:  uart_tx_random_sequence();
        default:             uart_tx_smoke_sequence();
    endcase
endtask

task automatic uart_tx_run_case(input int seq_kind);
    string case_name;

    case (seq_kind)
        UART_TX_SEQ_SMOKE:   case_name = "SMOKE";
        UART_TX_SEQ_PATTERN: case_name = "PATTERN";
        UART_TX_SEQ_RANDOM:  case_name = "RANDOM";
        default:             case_name = "UNKNOWN";
    endcase

    uart_tx_sequencer_reset();
    uart_tx_scoreboard_reset();

    $display("[TEST] UVC_BLOCK_CASE_START kind=%s bytes=%0d", case_name, UART_TX_NUM_BYTES);
    uart_tx_print_payload();

    fork
        begin : SEQUENCE_THREAD
            uart_tx_run_selected_sequence(seq_kind);
        end
        begin : ENV_THREAD
            uart_tx_env(UART_TX_NUM_BYTES);
        end
    join

    uart_tx_scoreboard_report();
    $display("[TEST] UVC_BLOCK_CASE_DONE kind=%s", case_name);
    repeat (2 * CLKS_PER_BIT) @(posedge r_Clk);
endtask

task automatic uart_tx_test();
    uart_tx_load_smoke_payload();
    uart_tx_run_case(UART_TX_SEQ_SMOKE);

    uart_tx_load_pattern_payload();
    uart_tx_run_case(UART_TX_SEQ_PATTERN);

    uart_tx_load_random_payload();
    uart_tx_run_case(UART_TX_SEQ_RANDOM);

    $display("[TEST] UVC_BLOCK_ALL_DONE cases=3");
endtask
