`timescale 1ns/1ps

// UART TX pin 묶음.
// DUT와 testbench class가 같은 interface 경계를 바라보며,
// driver와 monitor에는 virtual interface handle로 전달한다.
interface uart_tx_if (
    input logic i_Clk,
    input logic i_Rsn
);
    logic [7:0] r_TxData;
    logic       r_TxValid;
    logic       w_TxReady;
    logic       w_TxSerial;
endinterface
