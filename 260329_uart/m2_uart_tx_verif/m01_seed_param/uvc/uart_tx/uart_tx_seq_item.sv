// m14의 plain sequence item을 실제 uvm_sequence_item으로 전환한다.
class uart_tx_seq_item extends uvm_sequence_item;
    rand logic [7:0] data;

    `uvm_object_utils(uart_tx_seq_item)

    function new(string name = "uart_tx_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("data=0x%02h", data);
    endfunction
endclass
