`timescale 1ns/1ps

// =============================================================================
// m14_sv_analysis_port : 순수 SystemVerilog analysis port bridge
//
// m13_sv_seq_item_port 대비 변화:
//   - sequence-driver의 seq_item_port / req 경로는 그대로 유지한다.
//   - monitor는 actual mailbox 대신 analysis_port.write(item)을 호출한다.
//   - env가 monitor port와 scoreboard imp를 연결한다.
//   - scoreboard는 write(actual) callback에서 expected와 actual을 비교한다.
//
// 핵심:
//   - expected item은 계속 sequence가 생성해 typed mailbox로 전달한다.
//   - 아직 UVM library는 사용하지 않는다.
//   - 다음 단계에서는 helper class를 실제 UVM component와 TLM port로 바꾼다.
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
        $display("[TEST] SV_ANALYSIS_PORT_OBJECTS_CONNECTED");
        test.run();

        repeat (5 * CLKS_PER_BIT) @(posedge r_Clk);
        $finish;
    end

endmodule
