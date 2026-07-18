package uart_tx_pkg;

    parameter int CLK_FREQ     = 50_000_000;
    parameter int BAUD_RATE    = 115_200;
    parameter int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // =========================================================================
    // uart_tx_seq_item
    //
    // sequence와 driver가 byte를 transaction 개념으로 바라보기 위한 wrapper다.
    // m09의 sequencer handoff는 아직 객체가 아니라 raw byte data를 전달한다.
    // =========================================================================
    class uart_tx_seq_item;
        logic [7:0] data;

        function new(input logic [7:0] data = 8'h00);
            this.data = data;
        endfunction
    endclass

endpackage
