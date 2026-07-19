`timescale 1ns/1ps

// =============================================================================
// m2/m08_multi_seed : multi-seed 회귀 실행
//
// m2/m07_stim_debug 대비 변화:
//   - 테스트벤치는 그대로 두고 sim/run_regression.ps1이 추가된다.
//   - 같은 검증을 여러 seed로 반복 실행하고 seed별 PASS와 coverage를
//     집계한다. 실패 seed가 하나라도 있으면 회귀 전체가 실패한다.
//   - seed별 로그는 sim/out/regress/에 보존된다.
//
// 핵심:
//   - 한 seed의 운으로 통과하는 자극 구멍을 줄이는 것이 회귀의 목적이다.
//   - seed 재현성(m01) 덕분에 실패 seed는 같은 명령으로 즉시 재현된다.
//   - m07의 검사망(smoke 실구동, -DataCovMin 하한)이 seed마다 적용된다.
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
