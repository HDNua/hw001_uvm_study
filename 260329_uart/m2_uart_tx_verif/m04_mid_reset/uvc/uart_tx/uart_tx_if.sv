`timescale 1ns/1ps

// UART TX pin 묶음.
// UVM component는 config_db로 전달받은 virtual interface handle을 사용한다.
// r_RsnDrive는 test가 전송 중 리셋을 주입하는 경로다. TB_Top이
// power-on reset과 AND해 실제 i_Rsn을 만든다.
interface uart_tx_if (
    input logic i_Clk,
    input logic i_Rsn
);
    logic [7:0] r_TxData;
    logic       r_TxValid;
    logic       w_TxReady;
    logic       w_TxSerial;
    logic       r_RsnDrive = 1'b1;   // 0: test가 리셋 주입
endinterface
