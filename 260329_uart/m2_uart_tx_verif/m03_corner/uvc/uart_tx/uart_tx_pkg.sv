package uart_tx_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    parameter int CLK_FREQ     = 50_000_000;
    parameter int BAUD_RATE    = 115_200;
    parameter int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    parameter int UART_TX_DEFAULT_NUM_BYTES = 5;

    // m02의 constraint 구조를 유지하고 핸드셰이크 경계 corner case를 더한다.
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
