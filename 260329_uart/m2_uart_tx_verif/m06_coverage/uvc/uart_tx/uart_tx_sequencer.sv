// m14의 mailbox helper를 실제 uvm_sequencer로 전환한다.
class uart_tx_sequencer extends uvm_sequencer #(uart_tx_seq_item);
    `uvm_component_utils(uart_tx_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass
