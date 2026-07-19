`timescale 1ns/1ps

// =============================================================================
// m2/m06_coverage : functional coverage 계량
//
// m2/m05_sva 대비 변화:
//   - driver가 실제 구동한 request item을 req_ap로 publish한다.
//   - uart_tx_coverage subscriber가 data/gap/busy coverpoint와
//     data x gap cross를 sample한다.
//   - report_phase가 coverpoint별 coverage를 출력하고 실행 스크립트가
//     최소 coverage 목표(-CovMin)를 검사한다.
//
// 핵심:
//   - "랜덤을 돌렸는데 무엇을 얼마나 쳤는가"를 계량하는 것이 coverage다.
//   - 목표에 미달하면 자극(byte 수, constraint)을 늘려 다시 도는
//     coverage closure 루프를 스크립트 인자로 체험할 수 있다.
//   - 이 단계의 측정은 의문을 하나 남긴다: data coverage가 seed와
//     byte 수에 무관하게 71.4%에 고정되고 pattern의 55/aa bins가
//     잡히지 않는다. 이 단서는 다음 단계에서 추적한다.
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
