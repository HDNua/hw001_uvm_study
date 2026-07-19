// 실제 UVM sequence.
//
// request는 start_item/finish_item으로 보내고 expected item은 env가 소유한
// analysis port로 publish하는 ownership을 유지한다.
// corner mode는 back-to-back(idle_gap=0)과 busy 중 valid 주입을 함께 강제한다.

class uart_tx_sequence extends uvm_sequence #(uart_tx_seq_item);
    logic [7:0] payload [];
    int unsigned random_count = 0;
    int unsigned corner_count = 0;
    string sequence_label = "uart_tx_sequence";
    uvm_analysis_port #(uart_tx_seq_item) expected_ap;

    `uvm_object_utils(uart_tx_sequence)

    function new(string name = "uart_tx_sequence");
        super.new(name);
    endfunction

    // 고정 payload case: data는 그대로 쓰고 idle_gap만 randomize한다.
    function void set_payload(
        input string label,
        input logic [7:0] data []
    );
        sequence_label = label;
        payload        = data;
        random_count   = 0;
        corner_count   = 0;
    endfunction

    // random case: constraint 기반 full randomize로 count개를 생성한다.
    function void set_random_payload(
        input string label,
        input int unsigned count
    );
        sequence_label = label;
        payload        = new[0];
        random_count   = count;
        corner_count   = 0;
    endfunction

    // corner case: back-to-back으로 보내며 매 byte 전송 중에 valid를 주입한다.
    function void set_corner_payload(
        input string label,
        input int unsigned count
    );
        sequence_label = label;
        payload        = new[0];
        random_count   = 0;
        corner_count   = count;
    endfunction

    function void set_expected_port(
        input uvm_analysis_port #(uart_tx_seq_item) expected_ap
    );
        this.expected_ap = expected_ap;
    endfunction

    task body();
        uart_tx_seq_item req_item;

        if (expected_ap == null)
            `uvm_fatal("NOEXPAP", "uart_tx_sequence requires expected analysis port")
        if (random_count == 0 && corner_count == 0 && payload.size() == 0)
            `uvm_fatal("NOPAYLOAD", "uart_tx_sequence requires payload or item count")

        `uvm_info("SEQ", $sformatf("%s start", sequence_label), UVM_LOW)
        if (corner_count > 0) begin
            repeat (corner_count) begin
                req_item = uart_tx_seq_item::type_id::create("req_item");
                if (!req_item.randomize() with { idle_gap == 0; })
                    `uvm_fatal("RANDFAIL", "uart_tx_seq_item corner randomize failed")
                req_item.inject_busy_valid = 1'b1;
                send_item(req_item);
            end
        end else if (random_count > 0) begin
            repeat (random_count) begin
                req_item = uart_tx_seq_item::type_id::create("req_item");
                if (!req_item.randomize())
                    `uvm_fatal("RANDFAIL", "uart_tx_seq_item randomize failed")
                send_item(req_item);
            end
        end else begin
            foreach (payload[r_ByteIdx]) begin
                req_item = uart_tx_seq_item::type_id::create("req_item");
                // 인자 목록 randomize(idle_gap)는 XSim에서 data까지 다시 뽑아
                // 고정 payload를 훼손한다(m06에서 coverage가 잡은 버그).
                // inline constraint로 data를 고정한 채 gap만 뽑는다.
                if (!req_item.randomize() with { data == payload[r_ByteIdx]; })
                    `uvm_fatal("RANDFAIL", "uart_tx_seq_item gap randomize failed")
                send_item(req_item);
            end
        end
    endtask

    task send_item(input uart_tx_seq_item req_item);
        uart_tx_seq_item expected_item;

        // busy 주입 데이터는 무시되어야 하므로 expected에 실리지 않는다.
        expected_item = uart_tx_seq_item::type_id::create("expected_item");
        expected_item.data = req_item.data;

        start_item(req_item);
        finish_item(req_item);
        expected_ap.write(expected_item);

        `uvm_info("SEQ", $sformatf("sent item/expected: 0x%02h gap=%0d busy_valid=%0b", req_item.data, req_item.idle_gap, req_item.inject_busy_valid), UVM_LOW)
    endtask
endclass
