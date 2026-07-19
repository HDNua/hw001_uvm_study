package uart_tx_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    parameter int CLK_FREQ     = 50_000_000;
    parameter int BAUD_RATE    = 115_200;
    parameter int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    parameter int UART_TX_DEFAULT_NUM_BYTES = 5;

    // m04의 시나리오를 유지하고 interface에 프로토콜 SVA 상시 감시를 더한다.
    `include "uart_tx_seq_item.sv"
    `include "uart_tx_sequence.sv"
    `include "uart_tx_sequencer.sv"
    `include "uart_tx_driver.sv"
    `include "uart_tx_monitor.sv"
    `include "uart_tx_scoreboard.sv"
    `include "uart_tx_agent.sv"
    `include "uart_tx_env.sv"
    `include "uart_tx_test.sv"
endpackage
