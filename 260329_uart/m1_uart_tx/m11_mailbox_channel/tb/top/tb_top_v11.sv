`timescale 1ns/1ps

// =============================================================================
// m11_mailbox_channel : typed mailbox 기반 transaction handoff
//
// m10_uvc_block 대비 변화:
//   - sequence -> driver의 raw byte queue + event를 item mailbox로 바꾼다.
//   - sequence -> scoreboard expected 경로도 item mailbox로 바꾼다.
//   - monitor -> scoreboard actual 경로도 item mailbox로 바꾼다.
//
// 핵심:
//   - mailbox put/get이 sequence item 객체를 producer와 consumer 사이에 전달한다.
//   - blocking get이 queue empty 검사와 event 대기를 대신한다.
//   - m10의 폴더, 역할 task와 세 case 재사용 구조는 그대로 유지한다.
//
// 한계:
//   - include된 역할은 아직 TB_Top scope의 task로 동작한다.
//   - 다음 단계에서 mailbox channel을 유지한 채 class 기반 UVC로 전환한다.
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
