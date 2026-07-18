`timescale 1ns/1ps

// =============================================================================
// m12_sv_class_uvc : plain SystemVerilog class 기반 UVC
//
// m11_mailbox_channel 대비 변화:
//   - task로 나뉘어 있던 sequence / driver / monitor / scoreboard /
//     agent / env / test를 class로 올린다.
//   - DUT pin 접근은 virtual uart_tx_if handle을 통해 수행한다.
//   - typed mailbox는 유지하고 handle을 constructor로 각 객체에 전달한다.
//   - TB_Top은 clock/reset, interface, DUT와 test 객체 생성만 담당한다.
//
// 핵심:
//   - test -> env -> agent -> driver/monitor 객체 ownership을 드러낸다.
//   - 역할별 상태와 run() 동작이 class 객체 안으로 들어간다.
//   - 아직 UVM library는 사용하지 않는다.
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
        $display("[TEST] SV_CLASS_UVC_OBJECTS_CREATED");
        test.run();

        repeat (5 * CLKS_PER_BIT) @(posedge r_Clk);
        $finish;
    end

endmodule
