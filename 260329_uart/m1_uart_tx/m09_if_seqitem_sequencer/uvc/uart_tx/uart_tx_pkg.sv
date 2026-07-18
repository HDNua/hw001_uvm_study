package uart_tx_pkg;

    parameter int CLK_FREQ     = 50_000_000;
    parameter int BAUD_RATE    = 115_200;
    parameter int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // =========================================================================
    // uart_tx_seq_item
    //
    // sequence가 driver에 넘기는 transaction 단위다.
    // 이 예제에서는 한 번의 UART TX 전송이 한 byte이므로 data만 가진다.
    // m08의 raw byte를 UVM식 sequence item 개념으로 감싼 중간 단계다.
    // =========================================================================
    class uart_tx_seq_item;
        logic [7:0] data;

        function new(input logic [7:0] data = 8'h00);
            this.data = data;
        endfunction
    endclass

endpackage
