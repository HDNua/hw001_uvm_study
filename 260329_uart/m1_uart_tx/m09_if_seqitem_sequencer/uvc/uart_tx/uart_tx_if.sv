`timescale 1ns/1ps

// =============================================================================
// m09_if_seqitem_sequencer : UART TX interface
//
// TB_Top에 흩어져 있던 UART TX pin 신호를 하나의 interface로 묶는다.
// 아직 virtual interface를 class에 넘기지는 않으며, 다음 단계에서
// driver와 monitor가 같은 pin 묶음을 공유하기 위한 기반만 만든다.
// =============================================================================

interface uart_tx_if (
    input logic i_Clk,
    input logic i_Rsn
);

    logic [7:0] r_TxData;
    logic       r_TxValid;
    logic       w_TxReady;
    logic       w_TxSerial;

endinterface
