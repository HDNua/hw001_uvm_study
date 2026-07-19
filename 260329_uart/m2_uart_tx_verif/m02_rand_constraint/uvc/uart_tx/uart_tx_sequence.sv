// 실제 UVM sequence.
//
// request는 start_item/finish_item으로 보내고 expected item은 env가 소유한
// analysis port로 publish하는 ownership을 유지한다.
// random case는 test가 만든 payload 대신 item.randomize()로 자극을 생성한다.

class uart_tx_sequence extends uvm_sequence #(uart_tx_seq_item);
    logic [7:0] payload [];
    int unsigned random_count = 0;
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
    endfunction

    // random case: constraint 기반 full randomize로 count개를 생성한다.
    function void set_random_payload(
        input string label,
        input int unsigned count
    );
        sequence_label = label;
        payload        = new[0];
        random_count   = count;
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
        if (random_count == 0 && payload.size() == 0)
            `uvm_fatal("NOPAYLOAD", "uart_tx_sequence requires payload or random count")

        `uvm_info("SEQ", $sformatf("%s start", sequence_label), UVM_LOW)
        if (random_count > 0) begin
            repeat (random_count) begin
                req_item = uart_tx_seq_item::type_id::create("req_item");
                if (!req_item.randomize())
                    `uvm_fatal("RANDFAIL", "uart_tx_seq_item randomize failed")
                send_item(req_item);
            end
        end else begin
            foreach (payload[r_ByteIdx]) begin
                req_item = uart_tx_seq_item::type_id::create("req_item");
                req_item.data = payload[r_ByteIdx];
                if (!req_item.randomize(idle_gap))
                    `uvm_fatal("RANDFAIL", "uart_tx_seq_item gap randomize failed")
                send_item(req_item);
            end
        end
    endtask

    task send_item(input uart_tx_seq_item req_item);
        uart_tx_seq_item expected_item;

        expected_item = uart_tx_seq_item::type_id::create("expected_item");
        expected_item.data = req_item.data;

        start_item(req_item);
        finish_item(req_item);
        expected_ap.write(expected_item);

        `uvm_info("SEQ", $sformatf("sent item/expected: 0x%02h gap=%0d", req_item.data, req_item.idle_gap), UVM_LOW)
    endtask
endclass
