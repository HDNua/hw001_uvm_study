`timescale 1ns/1ps

// =============================================================================
// m10_uvc_block : include 기반 UART TX UVC 파일 구조
//
// m09_if_seqitem_sequencer 대비 변화:
//   - top에 있던 역할 task를 uvc/uart_tx/*.sv와 tb/test/*.sv로 분리한다.
//   - interface / package / sequence item / sequencer / sequence / driver /
//     monitor / scoreboard / agent / env / test 파일 경계를 만든다.
//   - smoke / pattern / random case를 같은 UVC에서 반복 실행한다.
//
// 핵심:
//   - 아직 class component 구조가 아니라 TB_Top scope의 include 기반 task UVC다.
//   - 파일과 폴더로 각 검증 역할의 ownership을 먼저 드러낸다.
//   - sequence item wrapper와 raw-data sequencer 경로는 m09 구조를 유지한다.
//
// 한계:
//   - include된 task와 queue는 여전히 TB_Top scope에서 동작한다.
//   - handoff는 queue + event이며 다음 단계에서 mailbox로 대체한다.
// =============================================================================

module TB_Top;
    import uart_tx_pkg::*;

    localparam int UART_TX_NUM_BYTES = 5;

    logic       r_Clk = 1'b0;
    logic       r_Rsn;
    logic [7:0] r_Payload [0:UART_TX_NUM_BYTES-1];

    always #10 r_Clk = ~r_Clk;   // 50 MHz

    uart_tx_if I_UART_TxIf (
        .i_Clk (r_Clk),
        .i_Rsn (r_Rsn)
    );

    UART_Tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) I_UART_Tx (
        .i_Clk      (I_UART_TxIf.i_Clk),
        .i_Rsn      (I_UART_TxIf.i_Rsn),
        .i_TxData   (I_UART_TxIf.r_TxData),
        .i_TxValid  (I_UART_TxIf.r_TxValid),
        .o_TxReady  (I_UART_TxIf.w_TxReady),
        .o_TxSerial (I_UART_TxIf.w_TxSerial)
    );

    `include "uart_tx_sequencer.sv"
    `include "uart_tx_scoreboard.sv"
    `include "uart_tx_sequence.sv"
    `include "uart_tx_driver.sv"
    `include "uart_tx_monitor.sv"
    `include "uart_tx_agent.sv"
    `include "uart_tx_env.sv"
    `include "uart_tx_test.sv"

    initial begin
        r_Rsn                  = 1'b0;
        I_UART_TxIf.r_TxData  = '0;
        I_UART_TxIf.r_TxValid = 1'b0;

        repeat (5) @(posedge r_Clk);
        r_Rsn = 1'b1;
        @(posedge r_Clk);

        uart_tx_test();

        repeat (5 * CLKS_PER_BIT) @(posedge r_Clk);
        $finish;
    end

endmodule
