// UART TX 한 번의 transaction.
// 현재는 한 byte만 가지며 이후 parity, stop bit, delay 필드로 확장할 수 있다.
class uart_tx_seq_item;
    logic [7:0] data;

    function new(input logic [7:0] data = 8'h00);
        this.data = data;
    endfunction
endclass
