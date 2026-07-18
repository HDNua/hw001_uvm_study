// UART TX test class.
//
// m11의 test task를 class로 올리고 UVC 객체 생성과 case 진행을 조율한다.

localparam int UART_TX_SEQ_SMOKE   = 0;
localparam int UART_TX_SEQ_PATTERN = 1;
localparam int UART_TX_SEQ_RANDOM  = 2;

class uart_tx_test;
    virtual uart_tx_if vif;

    mailbox #(uart_tx_seq_item) exp_mbx;
    mailbox #(uart_tx_seq_item) mon_mbx;

    // test가 소유하며 sequence와 env 쪽에 같은 handle을 전달한다.
    uart_tx_sequencer sequencer;
    uart_tx_sequence  seq;
    uart_tx_env       env;

    logic [7:0] payload [0:UART_TX_NUM_BYTES-1];

    function new(virtual uart_tx_if vif);
        this.vif = vif;

        exp_mbx = new();
        mon_mbx = new();

        sequencer = new();
        seq       = new(sequencer, exp_mbx);
        env       = new(vif, sequencer, exp_mbx, mon_mbx);
    endfunction

    task load_smoke_payload();
        payload[0] = 8'h48;  // 'H'
        payload[1] = 8'h65;  // 'e'
        payload[2] = 8'h6c;  // 'l'
        payload[3] = 8'h6c;  // 'l'
        payload[4] = 8'h6f;  // 'o'
    endtask

    task load_pattern_payload();
        payload[0] = 8'h00;
        payload[1] = 8'hff;
        payload[2] = 8'h55;
        payload[3] = 8'haa;
        payload[4] = 8'h3c;
    endtask

    task load_random_payload();
        foreach (payload[r_ByteIdx])
            payload[r_ByteIdx] = $urandom_range(8'h00, 8'hff);
    endtask

    task print_payload();
        $write("[TEST] Payload bytes:");
        foreach (payload[r_ByteIdx])
            $write(" %02h", payload[r_ByteIdx]);
        $write("\n");
    endtask

    function string get_sequence_name(input int seq_kind);
        case (seq_kind)
            UART_TX_SEQ_SMOKE:   return "smoke_sequence";
            UART_TX_SEQ_PATTERN: return "pattern_sequence";
            UART_TX_SEQ_RANDOM:  return "random_sequence";
            default:             return "unknown_sequence";
        endcase
    endfunction

    task run_case(input int seq_kind);
        string sequence_name;
        string case_name;

        sequence_name = get_sequence_name(seq_kind);
        case (seq_kind)
            UART_TX_SEQ_SMOKE:   case_name = "SMOKE";
            UART_TX_SEQ_PATTERN: case_name = "PATTERN";
            UART_TX_SEQ_RANDOM:  case_name = "RANDOM";
            default:             case_name = "UNKNOWN";
        endcase

        sequencer.reset();
        env.scoreboard.reset();

        $display("[TEST] SV_CLASS_UVC_CASE_START kind=%s bytes=%0d", case_name, UART_TX_NUM_BYTES);
        print_payload();

        fork
            begin : SEQUENCE_THREAD
                seq.send_payload(sequence_name, payload);
            end
            begin : ENV_THREAD
                env.run(UART_TX_NUM_BYTES);
            end
        join

        env.scoreboard.report();
        $display("[TEST] SV_CLASS_UVC_CASE_DONE kind=%s", case_name);
        repeat (2 * CLKS_PER_BIT) @(posedge vif.i_Clk);
    endtask

    task run();
        load_smoke_payload();
        run_case(UART_TX_SEQ_SMOKE);

        load_pattern_payload();
        run_case(UART_TX_SEQ_PATTERN);

        load_random_payload();
        run_case(UART_TX_SEQ_RANDOM);

        $display("[TEST] SV_CLASS_UVC_ALL_DONE cases=3");
    endtask
endclass
