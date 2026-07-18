`timescale 1ns/1ps

// =============================================================================
// m15_uvm_minimal : 실제 UVM object, component, phase와 TLM port
//
// m14_sv_analysis_port 대비 변화:
//   - sequence item과 sequence가 uvm_sequence_item / uvm_sequence를 상속한다.
//   - driver, sequencer, monitor, scoreboard, agent, env와 test가 UVM component가 된다.
//   - constructor 기반 실행을 build/connect/run phase와 factory 생성으로 바꾼다.
//   - virtual interface는 uvm_config_db로 전달한다.
//   - request와 expected/actual 경로는 실제 UVM TLM port를 사용한다.
//
// 핵심:
//   - m14의 역할과 데이터 ownership이 UVM 표준 구조에 어떻게 매핑되는지 보여준다.
//   - config object, factory override와 register model은 아직 도입하지 않는다.
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
        $display("[TOP] UVM_MINIMAL_RUN_TEST_START");
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
