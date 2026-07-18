// 실제 UVM test.
// factory로 env와 sequence를 만들고 run_phase objection 안에서 세 case를 실행한다.

class uart_tx_test extends uvm_test;
    uart_tx_env env;
    virtual uart_tx_if vif;
    logic [7:0] payload [0:UART_TX_NUM_BYTES-1];

    localparam int UART_TX_SEQ_SMOKE   = 0;
    localparam int UART_TX_SEQ_PATTERN = 1;
    localparam int UART_TX_SEQ_RANDOM  = 2;

    `uvm_component_utils(uart_tx_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual uart_tx_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "uart_tx_test requires virtual uart_tx_if")

        env = uart_tx_env::type_id::create("env", this);
        `uvm_info("TEST", "UVM_MINIMAL_COMPONENTS_BUILT", UVM_LOW)
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        wait (vif.i_Rsn === 1'b1);
        @(posedge vif.i_Clk);

        load_smoke_payload();
        run_case(UART_TX_SEQ_SMOKE);

        load_pattern_payload();
        run_case(UART_TX_SEQ_PATTERN);

        load_random_payload();
        run_case(UART_TX_SEQ_RANDOM);

        `uvm_info("TEST", "UVM_MINIMAL_ALL_DONE cases=3", UVM_LOW)
        phase.drop_objection(this);
    endtask

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

    function void print_payload();
        string message;

        message = "Payload bytes:";
        foreach (payload[r_ByteIdx])
            message = {message, $sformatf(" %02h", payload[r_ByteIdx])};
        `uvm_info("TEST", message, UVM_LOW)
    endfunction

    task run_case(input int seq_kind);
        uart_tx_sequence seq;
        string sequence_name;
        string case_name;

        case (seq_kind)
            UART_TX_SEQ_SMOKE: begin
                sequence_name = "smoke_sequence";
                case_name     = "SMOKE";
            end
            UART_TX_SEQ_PATTERN: begin
                sequence_name = "pattern_sequence";
                case_name     = "PATTERN";
            end
            UART_TX_SEQ_RANDOM: begin
                sequence_name = "random_sequence";
                case_name     = "RANDOM";
            end
            default: begin
                sequence_name = "unknown_sequence";
                case_name     = "UNKNOWN";
            end
        endcase

        env.scoreboard.reset_case(UART_TX_NUM_BYTES);
        `uvm_info("TEST", $sformatf("UVM_MINIMAL_CASE_START kind=%s bytes=%0d", case_name, UART_TX_NUM_BYTES), UVM_LOW)
        print_payload();

        seq = uart_tx_sequence::type_id::create("seq");
        seq.set_payload(sequence_name, payload);
        seq.set_expected_port(env.expected_ap);
        seq.start(env.agent.sequencer);

        env.scoreboard.wait_done();
        env.scoreboard.report_case();
        `uvm_info("TEST", $sformatf("UVM_MINIMAL_CASE_DONE kind=%s", case_name), UVM_LOW)
        repeat (2 * CLKS_PER_BIT) @(posedge vif.i_Clk);
    endtask
endclass
