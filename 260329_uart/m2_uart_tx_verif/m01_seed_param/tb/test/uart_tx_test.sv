// 실제 UVM test.
// seed와 자극 byte 수를 plusarg로 받아 같은 UVM 구조에서 자극 크기를 바꾼다.

class uart_tx_test extends uvm_test;
    uart_tx_env env;
    virtual uart_tx_if vif;
    int unsigned seed      = 1;
    int unsigned num_bytes = UART_TX_DEFAULT_NUM_BYTES;
    logic [7:0] payload [];

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

        if (!$value$plusargs("SEED=%d", seed))
            seed = 1;
        if (!$value$plusargs("NUM_BYTES=%d", num_bytes))
            num_bytes = UART_TX_DEFAULT_NUM_BYTES;
        if (num_bytes == 0)
            `uvm_fatal("CFG", "NUM_BYTES must be >= 1")

        env = uart_tx_env::type_id::create("env", this);
        `uvm_info("TEST", "UART_TX_VERIF_COMPONENTS_BUILT", UVM_LOW)
        `uvm_info("TEST", $sformatf("UART_TX_VERIF_CONFIG seed=%0d num_bytes=%0d", seed, num_bytes), UVM_LOW)
    endfunction

    task run_phase(uvm_phase phase);
        process rand_process;

        phase.raise_objection(this);

        // 같은 seed는 같은 자극을 재현한다.
        rand_process = process::self();
        rand_process.srandom(seed);
        payload = new[num_bytes];

        wait (vif.i_Rsn === 1'b1);
        @(posedge vif.i_Clk);

        load_smoke_payload();
        run_case(UART_TX_SEQ_SMOKE);

        load_pattern_payload();
        run_case(UART_TX_SEQ_PATTERN);

        load_random_payload();
        run_case(UART_TX_SEQ_RANDOM);

        `uvm_info("TEST", "UART_TX_VERIF_ALL_DONE cases=3", UVM_LOW)
        phase.drop_objection(this);
    endtask

    task load_smoke_payload();
        logic [7:0] base [0:4];

        // "Hello"를 num_bytes 길이에 맞춰 순환 적재한다.
        base = '{8'h48, 8'h65, 8'h6c, 8'h6c, 8'h6f};
        foreach (payload[r_ByteIdx])
            payload[r_ByteIdx] = base[r_ByteIdx % 5];
    endtask

    task load_pattern_payload();
        logic [7:0] base [0:4];

        // 경계 pattern을 num_bytes 길이에 맞춰 순환 적재한다.
        base = '{8'h00, 8'hff, 8'h55, 8'haa, 8'h3c};
        foreach (payload[r_ByteIdx])
            payload[r_ByteIdx] = base[r_ByteIdx % 5];
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

        env.scoreboard.reset_case(num_bytes);
        `uvm_info("TEST", $sformatf("UART_TX_VERIF_CASE_START kind=%s bytes=%0d", case_name, num_bytes), UVM_LOW)
        print_payload();

        seq = uart_tx_sequence::type_id::create("seq");
        seq.set_payload(sequence_name, payload);
        seq.set_expected_port(env.expected_ap);
        seq.start(env.agent.sequencer);

        env.scoreboard.wait_done();
        env.scoreboard.report_case();
        `uvm_info("TEST", $sformatf("UART_TX_VERIF_CASE_DONE kind=%s", case_name), UVM_LOW)
        repeat (2 * CLKS_PER_BIT) @(posedge vif.i_Clk);
    endtask
endclass
