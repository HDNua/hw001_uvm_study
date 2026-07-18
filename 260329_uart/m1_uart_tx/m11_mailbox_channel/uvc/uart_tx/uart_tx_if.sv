`timescale 1ns/1ps

// UART TX pin 묶음.
// DUT, driver와 monitor가 같은 interface 경계를 바라보게 한다.
// 아직 class에 virtual interface로 전달하지 않는 task 기반 단계다.
interface uart_tx_if (
    input logic i_Clk,
    input logic i_Rsn
);
    logic [7:0] r_TxData;
    logic       r_TxValid;
    logic       w_TxReady;
    logic       w_TxSerial;
endinterface
