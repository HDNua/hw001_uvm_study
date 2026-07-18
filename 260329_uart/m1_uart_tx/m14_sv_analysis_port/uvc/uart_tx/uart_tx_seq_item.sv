// UART TX 한 번의 transaction을 나타내는 sequence item.
class uart_tx_seq_item;
    logic [7:0] data;

    function new(logic [7:0] data = 8'h00);
        this.data = data;
    endfunction
endclass
