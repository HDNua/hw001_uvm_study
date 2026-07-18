`timescale 1ns/1ps

// =============================================================================
// m13_sv_seq_item_port : 순수 SystemVerilog seq_item_port bridge
//
// m12_sv_class_uvc 대비 변화:
//   - sequence는 이전처럼 sequencer에 item을 넣는다.
//   - driver는 sequencer를 직접 알지 않고 seq_item_port를 통해 req를 받는다.
//   - get_next_item(req) -> drive_item(req) -> item_done() 순서를 사용한다.
//
// 핵심:
//   - class UVC, virtual interface, typed mailbox 구조는 그대로 유지한다.
//   - 아직 UVM library는 사용하지 않는다.
//   - 다음 단계에서는 monitor의 actual 경로에 analysis_port 모양을 도입한다.
// =============================================================================

module TB_Top;
    import uart_tx_pkg::*;

    logic r_Clk = 1'b0;
    logic r_Rsn;

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

    initial begin
        uart_tx_test test;

        r_Rsn                  = 1'b0;
        I_UART_TxIf.r_TxData  = '0;
        I_UART_TxIf.r_TxValid = 1'b0;

        repeat (5) @(posedge r_Clk);
        r_Rsn = 1'b1;
        @(posedge r_Clk);

        test = new(I_UART_TxIf);
        $display("[TEST] SV_SEQ_ITEM_PORT_OBJECTS_CREATED");
        test.run();

        repeat (5 * CLKS_PER_BIT) @(posedge r_Clk);
        $finish;
    end

endmodule
