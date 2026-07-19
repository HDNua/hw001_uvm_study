`timescale 1ns/1ps

// UART TX pin 묶음과 프로토콜 SVA.
// UVM component는 config_db로 전달받은 virtual interface handle을 사용한다.
// r_RsnDrive는 test가 전송 중 리셋을 주입하는 경로다. TB_Top이
// power-on reset과 AND해 실제 i_Rsn을 만든다.
//
// 이 단계부터 interface가 프레임 타이밍 속성을 SVA로 상시 감시한다.
// scoreboard가 "데이터 값"을 검사한다면 SVA는 "프로토콜 파형"을 검사한다.
interface uart_tx_if #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115_200
) (
    input logic i_Clk,
    input logic i_Rsn
);
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    logic [7:0] r_TxData;
    logic       r_TxValid;
    logic       w_TxReady;
    logic       w_TxSerial;
    logic       r_RsnDrive = 1'b1;   // 0: test가 리셋 주입

    // -------------------------------------------------------------------------
    // 프로토콜 SVA
    // 전송 수락(r_TxValid && w_TxReady) 시점을 기준으로 검사한다.
    // 전송 중 리셋(m04 case)은 disable iff로 안전하게 무효화된다.
    // -------------------------------------------------------------------------

    // idle(ready=1)에서는 직렬 출력이 1이어야 한다.
    property p_idle_serial_high;
        @(posedge i_Clk) disable iff (!i_Rsn)
        w_TxReady |-> w_TxSerial;
    endproperty
    a_idle_serial_high: assert property (p_idle_serial_high)
        else $error("SVA a_idle_serial_high: serial low while ready");

    // 수락 후 start bit(0)가 정확히 1 bit 시간 동안 유지된다.
    property p_start_bit_width;
        @(posedge i_Clk) disable iff (!i_Rsn)
        (r_TxValid && w_TxReady) |=> ##1 ((!w_TxSerial) [* CLKS_PER_BIT]);
    endproperty
    a_start_bit_width: assert property (p_start_bit_width)
        else $error("SVA a_start_bit_width: start bit shape violated");

    // 수락 후 ready는 정확히 10 bit 시간(start+8data+stop) 동안 0을
    // 유지한 뒤 1로 복귀한다.
    property p_ready_frame_low;
        @(posedge i_Clk) disable iff (!i_Rsn)
        (r_TxValid && w_TxReady) |=> ((!w_TxReady) [* (10 * CLKS_PER_BIT)]) ##1 w_TxReady;
    endproperty
    a_ready_frame_low: assert property (p_ready_frame_low)
        else $error("SVA a_ready_frame_low: ready frame timing violated");

    // 프레임 마지막 1 bit 시간은 stop bit(1)이어야 한다.
    property p_stop_bit_high;
        @(posedge i_Clk) disable iff (!i_Rsn)
        (r_TxValid && w_TxReady) |=> ##(9 * CLKS_PER_BIT + 1) (w_TxSerial [* CLKS_PER_BIT]);
    endproperty
    a_stop_bit_high: assert property (p_stop_bit_high)
        else $error("SVA a_stop_bit_high: stop bit shape violated");

    initial $display("[IF] UART_TX_VERIF_SVA_ACTIVE props=4");
endinterface
