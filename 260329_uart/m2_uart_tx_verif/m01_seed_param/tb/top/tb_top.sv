`timescale 1ns/1ps

// =============================================================================
// m2/m01_seed_param : seed와 자극 크기의 실행 시점 파라미터화
//
// m1_uart_tx/m15_uvm_minimal 대비 변화:
//   - test가 +SEED, +NUM_BYTES plusarg를 읽어 자극을 구성한다.
//   - payload와 sequence가 고정 크기 배열 대신 dynamic array를 사용한다.
//   - run_phase가 process::self().srandom(seed)로 랜덤 재현성을 확보한다.
//   - 실행 스크립트가 고정 건수 일치 대신 경로 불변식을 검사한다.
//
// 핵심:
//   - UVM 구조는 m15를 그대로 유지한다. 이 모듈(m2)은 구조가 아니라
//     자극과 체킹의 깊이를 단계적으로 확장한다.
//   - 같은 seed는 같은 자극을 재현한다.
//   - 스크립트 불변식: sequence == driver == monitor == scoreboard PASS 건수.
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
