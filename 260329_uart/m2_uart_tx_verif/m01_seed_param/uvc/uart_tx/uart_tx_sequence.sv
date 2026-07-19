// 실제 UVM sequence.
//
// request는 start_item/finish_item으로 보내고 expected item은 env가 소유한
// analysis port로 publish하는 m15의 ownership을 유지한다.
// payload는 dynamic array로 받아 자극 길이를 실행 시점에 정한다.

class uart_tx_sequence extends uvm_sequence #(uart_tx_seq_item);
    logic [7:0] payload [];
    string sequence_label = "uart_tx_sequence";
    uvm_analysis_port #(uart_tx_seq_item) expected_ap;

    `uvm_object_utils(uart_tx_sequence)

    function new(string name = "uart_tx_sequence");
        super.new(name);
    endfunction

    function void set_payload(
        input string label,
        input logic [7:0] data []
    );
        sequence_label = label;
        payload        = data;
    endfunction

    function void set_expected_port(
        input uvm_analysis_port #(uart_tx_seq_item) expected_ap
    );
        this.expected_ap = expected_ap;
    endfunction

    task body();
        uart_tx_seq_item req_item;
        uart_tx_seq_item expected_item;

        if (expected_ap == null)
            `uvm_fatal("NOEXPAP", "uart_tx_sequence requires expected analysis port")
        if (payload.size() == 0)
            `uvm_fatal("NOPAYLOAD", "uart_tx_sequence requires a non-empty payload")

        `uvm_info("SEQ", $sformatf("%s start", sequence_label), UVM_LOW)
        foreach (payload[r_ByteIdx]) begin
            req_item = uart_tx_seq_item::type_id::create("req_item");
            expected_item = uart_tx_seq_item::type_id::create("expected_item");
            req_item.data      = payload[r_ByteIdx];
            expected_item.data = payload[r_ByteIdx];

            start_item(req_item);
            finish_item(req_item);
            expected_ap.write(expected_item);

            `uvm_info("SEQ", $sformatf("sent item/expected: 0x%02h", req_item.data), UVM_LOW)
        end
    endtask
endclass
