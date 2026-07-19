`timescale 1ns/1ps

// =============================================================================
// m2/m07_stim_debug : coverage 단서로 자극 버그를 추적·수정
//
// m2/m06_coverage 대비 변화:
//   - m06의 단서(data 71.4% 고정, 55/aa bins 0 hit)를 로그 대조로
//     추적한다: smoke case의 [DRV] driving req가 0x48이 아니다.
//   - 원인: XSim의 인자 목록 randomize(idle_gap)가 rand 필드 전체를
//     다시 뽑아 고정 payload를 덮는다. 이 버그는 m02부터 잠복해 있었다.
//   - expected가 randomize 이후 값을 복사하므로 scoreboard는 침묵했다.
//     coverage가 이 버그를 드러낸 유일한 감시망이었다.
//   - sequence의 고정 payload 경로를 inline constraint로 교정한다.
//   - 스크립트에 smoke 실구동 검사와 고정 payload가 보장하는
//     data coverage 하한(-DataCovMin, 기본 85%)을 상설화한다.
//
// 핵심:
//   - self-checking TB도 자극이 훼손되면 조용히 통과할 수 있다.
//     "무엇을 쳤는가"를 계량하는 coverage가 그 구멍을 드러낸다.
//   - 수정 후 data coverage는 100%로 회복된다.
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
