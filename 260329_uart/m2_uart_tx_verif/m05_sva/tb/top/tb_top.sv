`timescale 1ns/1ps

// =============================================================================
// m2/m05_sva : 프로토콜 SVA 상시 감시
//
// m2/m04_mid_reset 대비 변화:
//   - uart_tx_if가 CLK_FREQ/BAUD_RATE 파라미터를 받고 프레임 타이밍
//     속성 4개를 SVA로 상시 감시한다.
//   - idle serial high, start bit 폭, ready 프레임 타이밍, stop bit 폭.
//   - monitor의 framing 검사가 warning에서 error로 승격된다.
//   - 실행 스크립트가 SVA 활성 marker와 assertion 실패 0을 검사한다.
//
// 핵심:
//   - scoreboard는 "데이터 값", SVA는 "프로토콜 파형"을 검사한다.
//     같은 자극에서 서로 다른 종류의 버그를 잡는 상보적 감시망이다.
//   - 전송 중 리셋은 disable iff (!i_Rsn)로 안전하게 무효화된다.
// =============================================================================

module TB_Top;
    import uvm_pkg::*;
    import uart_tx_pkg::*;

    logic r_Clk    = 1'b0;
    logic r_RsnPor = 1'b0;
    logic w_Rsn;

    always #10 r_Clk = ~r_Clk;   // 50 MHz

    // power-on reset과 test의 리셋 주입(r_RsnDrive)을 AND해 i_Rsn을 만든다.
    assign w_Rsn = r_RsnPor & I_UART_TxIf.r_RsnDrive;

    uart_tx_if #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) I_UART_TxIf (
        .i_Clk (r_Clk),
        .i_Rsn (w_Rsn)
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
        I_UART_TxIf.r_TxData  = '0;
        I_UART_TxIf.r_TxValid = 1'b0;

        repeat (5) @(posedge r_Clk);
        r_RsnPor = 1'b1;
    end

endmodule
