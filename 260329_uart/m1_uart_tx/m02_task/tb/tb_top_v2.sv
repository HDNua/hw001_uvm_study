`timescale 1ns/1ps

// =============================================================================
// m02_task : task 분리, 순차 실행
//
// m01_pure 대비 변화:
//   - send_byte / recv_byte task로 분리
//   - 그러나 initial에서 순차 호출
//
// 한계:
//   - send_byte는 r_TxValid 펄스만 주고 즉시 반환한다.
//     전송이 아직 진행 중인 상태에서 recv_byte가 이어 실행되므로 1바이트는 동작한다.
//   - 그러나 여러 바이트를 보내려면 send_byte 완료 시점을 알아야 하고,
//     그 사이에 monitor가 동작해야 한다.
//     → 순차 실행으로는 구조적으로 해결이 안 된다. fork가 필요한 이유.
//
// -----------------------------------------------------------------------------
// Insight: 왜 UART testbench는 fork 없이는 말이 안 되는가
// -----------------------------------------------------------------------------
//
// UART는 서로 다른 장치 간 비동기 직렬 통신이다.
// 실제 시스템에서 TX 장치와 RX 장치는 물리적으로 동시에 동작한다.
// TX가 비트를 쏘는 동안, RX는 그 선을 듣고 있다.
//
// testbench에서 이를 모델링하려면 driver와 monitor가 동시에 실행되어야 한다.
//
// 그러나 순차 실행에서는:
//
//   send_byte('H')  → valid 올리고 즉시 반환
//   send_byte('e')  → w_TxReady 기다리는 중(블로킹)
//                     ← 이 동안 recv_byte 는 실행 못 함
//                     ← 'H' 프레임은 지금 지나가고 있음
//   send_byte('e')  → 완료
//   recv_byte()     → 이제 실행 — 근데 'H' 프레임은 이미 지나감
//
// driver가 블로킹되는 동안 monitor가 동시에 들을 수 없기 때문에,
// 순차 실행으로는 UART의 본질 자체를 표현할 수 없다.
//
// fork는 단순한 편의 기능이 아니라,
// "동시에 동작하는 두 장치"를 시뮬레이션하기 위한 필수 구조다.
// =============================================================================

module TB_Top;

    localparam int CLK_FREQ     = 50_000_000;
    localparam int BAUD_RATE    = 115_200;
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    logic r_Clk = 1'b0;
    logic r_Rsn;

    always #10 r_Clk = ~r_Clk;   // 50 MHz

    logic [7:0] r_TxData;
    logic       r_TxValid;
    logic       w_TxReady;
    logic       w_TxSerial;

    UART_Tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) I_UART_Tx (
        .i_Clk      (r_Clk),
        .i_Rsn      (r_Rsn),
        .i_TxData   (r_TxData),
        .i_TxValid  (r_TxValid),
        .o_TxReady  (w_TxReady),
        .o_TxSerial (w_TxSerial)
    );

    // -------------------------------------------------------------------------
    // task: send_byte
    // r_TxValid 1사이클 펄스 후 즉시 반환(전송 완료를 기다리지 않음)
    // -------------------------------------------------------------------------
    task send_byte(input logic [7:0] data);
        // CPU 출력 레지스터처럼 상승 엣지에서 요청을 등록한다.
        // DUT는 다음 상승 엣지에서 valid/data를 샘플링한다.
        do @(posedge r_Clk); while (!w_TxReady);
        r_TxData  <= data;
        r_TxValid <= 1'b1;
        @(posedge r_Clk);
        r_TxValid <= 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // task: recv_byte
    // start bit 하강 엣지 감지 후 8비트 샘플링
    // -------------------------------------------------------------------------
    task recv_byte(output logic [7:0] captured);
        @(negedge w_TxSerial);
        repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge r_Clk);
        for (int r_BitIdx = 0; r_BitIdx < 8; r_BitIdx++) begin
            captured[r_BitIdx] = w_TxSerial;
            if (r_BitIdx < 7)
                repeat (CLKS_PER_BIT) @(posedge r_Clk);
        end
    endtask

    // -------------------------------------------------------------------------
    // 테스트
    // -------------------------------------------------------------------------
    logic [7:0] r_Captured;

    initial begin
        r_Rsn      = 1'b0;
        r_TxValid  = 1'b0;
        r_TxData   = '0;
        r_Captured = '0;
        repeat (5) @(posedge r_Clk);
        r_Rsn = 1'b1;
        @(posedge r_Clk);

        send_byte(8'h48);   // 전송 시작, 즉시 반환
        recv_byte(r_Captured); // 전송 진행 중이므로 start bit 감지 가능

        if (r_Captured === 8'h48) begin
            $display("PASS: captured=0x%02h", r_Captured);
        end else begin
            $fatal(1, "FAIL: expected=0x48 captured=0x%02h", r_Captured);
        end

        repeat (CLKS_PER_BIT) @(posedge r_Clk);
        $finish;
    end

endmodule
