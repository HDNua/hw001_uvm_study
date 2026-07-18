package uart_tx_pkg;
    // UART TX UVC 전체가 공유하는 설정값.
    parameter int CLK_FREQ     = 50_000_000;
    parameter int BAUD_RATE    = 115_200;
    parameter int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // sequence item 정의를 package 안에 포함해 import한 scope에서 사용한다.
    `include "uart_tx_seq_item.sv"
endpackage
