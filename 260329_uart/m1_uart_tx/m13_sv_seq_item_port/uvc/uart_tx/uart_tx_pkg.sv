package uart_tx_pkg;
    // UART TX UVC 전체가 공유하는 설정값.
    parameter int CLK_FREQ     = 50_000_000;
    parameter int BAUD_RATE    = 115_200;
    parameter int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    parameter int UART_TX_NUM_BYTES = 5;

    // m12 class UVC에 순수 SV seq_item_port bridge를 추가한다.
    `include "uart_tx_seq_item.sv"
    `include "uart_tx_sequencer.sv"
    `include "uart_tx_seq_item_port.sv"
    `include "uart_tx_sequence.sv"
    `include "uart_tx_scoreboard.sv"
    `include "uart_tx_driver.sv"
    `include "uart_tx_monitor.sv"
    `include "uart_tx_agent.sv"
    `include "uart_tx_env.sv"
    `include "uart_tx_test.sv"
endpackage
