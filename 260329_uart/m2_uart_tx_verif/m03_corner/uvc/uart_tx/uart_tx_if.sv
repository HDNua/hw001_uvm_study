`timescale 1ns/1ps

// UART TX pin 묶음.
// UVM component는 config_db로 전달받은 virtual interface handle을 사용한다.
interface uart_tx_if (
    input logic i_Clk,
    input logic i_Rsn
);
    logic [7:0] r_TxData;
    logic       r_TxValid;
    logic       w_TxReady;
    logic       w_TxSerial;
endinterface
