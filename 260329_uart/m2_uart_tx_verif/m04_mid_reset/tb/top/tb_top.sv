`timescale 1ns/1ps

// =============================================================================
// m2/m04_mid_reset : 전송 중 리셋 주입과 복구
//
// m2/m03_corner 대비 변화:
//   - reset case가 추가되어 총 5개 case를 실행한다.
//   - test가 두 번째 프레임 중간에 vif.r_RsnDrive로 리셋을 주입한다.
//   - monitor는 리셋으로 잘린 capture를 버리고 재동기화한다.
//   - scoreboard는 in-flight expected를 목표에서 제외한다(on_reset).
//   - driver는 리셋 해제와 ready를 함께 기다린 뒤 다음 byte를 구동한다.
//
// 핵심:
//   - 리셋으로 잘린 byte는 유실이 정상이며, 이후 byte들이 깨끗하게
//     전송·검증되는 복구 경로가 이 단계의 검증 대상이다.
//   - TB_Top이 power-on reset과 test 주입 리셋을 AND해 i_Rsn을 만든다.
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

    uart_tx_if I_UART_TxIf (
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
