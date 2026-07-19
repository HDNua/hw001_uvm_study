`timescale 1ns/1ps

// =============================================================================
// m2/m02_rand_constraint : sequence item의 rand 필드와 constraint
//
// m2/m01_seed_param 대비 변화:
//   - uart_tx_seq_item에 rand data, rand idle_gap과 constraint가 생긴다.
//   - random case는 test의 $urandom_range 대신 item.randomize()로 생성된다.
//   - 고정 payload case도 idle_gap을 randomize해 byte 간격을 흔든다.
//   - driver가 idle_gap만큼 대기한 뒤 구동해 시간축 변화를 만든다.
//
// 핵심:
//   - 자극 값의 ownership이 test 코드에서 item constraint로 이동한다.
//   - 경계값 가중치(dist)와 간격 범위를 constraint가 문서화한다.
//   - seed 재현성과 스크립트 경로 불변식은 m01 구조를 그대로 유지한다.
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
