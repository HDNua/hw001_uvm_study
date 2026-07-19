`timescale 1ns/1ps

// =============================================================================
// m2/m03_corner : 핸드셰이크 경계의 corner case
//
// m2/m02_rand_constraint 대비 변화:
//   - corner case가 추가되어 총 4개 case를 실행한다.
//   - corner case는 idle_gap=0(back-to-back)을 강제한다.
//   - 매 byte 전송 중(o_TxReady=0)에 valid를 다시 주입한다.
//   - 주입된 busy_data는 expected에 실리지 않으며, DUT가 무시하지 않으면
//     scoreboard의 unexpected actual 오류로 드러난다.
//
// 핵심:
//   - "전송 중 valid는 조용히 무시된다"는 핸드셰이크 규약이 자극과
//     체킹으로 처음 확정된다. m00_rtl/UART_Tx.sv 헤더의 규약 절 참조.
//   - back-to-back은 ready 복귀 즉시 다음 요청이 접수됨을 확인한다.
// =============================================================================

module TB_Top;
    import uvm_pkg::*;
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
        uvm_config_db #(virtual uart_tx_if)::set(null, "*", "vif", I_UART_TxIf);
        $display("[TOP] UART_TX_VERIF_RUN_TEST_START");
        run_test("uart_tx_test");
    end

    initial begin
        r_Rsn                  = 1'b0;
        I_UART_TxIf.r_TxData  = '0;
        I_UART_TxIf.r_TxValid = 1'b0;

        repeat (5) @(posedge r_Clk);
        r_Rsn = 1'b1;
    end

endmodule
