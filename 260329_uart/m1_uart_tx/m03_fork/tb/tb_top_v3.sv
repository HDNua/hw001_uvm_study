`timescale 1ns/1ps

// =============================================================================
// m03_fork : fork/join 병렬 실행
//
// m02_task 대비 변화:
//   - 다음 바이트를 보내기 전에 o_TxReady 복귀를 기다린다.
//   - fork/join으로 driver와 monitor를 병렬 실행한다.
//   - payload를 "Hello" 5바이트로 확장한다.
//
// 한계:
//   - driver와 monitor가 payload를 직접 공유한다.
//   - pass/fail 판정이 monitor task 내부에 섞여 있다.
//     → 비교 로직을 분리한 scoreboard가 필요한 이유.
// =============================================================================

module TB_Top;

    localparam int CLK_FREQ     = 50_000_000;
    localparam int BAUD_RATE    = 115_200;
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam int PAYLOAD_SIZE = 5;

    // -------------------------------------------------------------------------
    // 클럭 및 리셋
    // -------------------------------------------------------------------------
    logic r_Clk = 1'b0;
    logic r_Rsn;

    always #10 r_Clk = ~r_Clk;   // 50 MHz

    // -------------------------------------------------------------------------
    // DUT 연결 신호
    // -------------------------------------------------------------------------
    logic [7:0] r_TxData;
    logic       r_TxValid;
    logic       w_TxReady;
    logic       w_TxSerial;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
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
    // 다음 호출은 w_TxReady가 복귀할 때까지 기다린 뒤 전송을 요청한다.
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
    // task: recv_and_check
    // 수신과 pass/fail 판정이 아직 하나의 monitor task에 섞여 있다.
    // -------------------------------------------------------------------------
    task recv_and_check(input logic [7:0] expected);
        logic [7:0] captured;

        @(negedge w_TxSerial);
        repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge r_Clk);
        for (int r_BitIdx = 0; r_BitIdx < 8; r_BitIdx++) begin
            captured[r_BitIdx] = w_TxSerial;
            if (r_BitIdx < 7)
                repeat (CLKS_PER_BIT) @(posedge r_Clk);
        end

        if (captured === expected) begin
            $display("PASS: expected=0x%02h captured=0x%02h", expected, captured);
        end else begin
            $fatal(1, "FAIL: expected=0x%02h captured=0x%02h", expected, captured);
        end
    endtask

    // -------------------------------------------------------------------------
    // 테스트 payload
    // -------------------------------------------------------------------------
    logic [7:0] r_Payload [0:PAYLOAD_SIZE-1];

    initial begin
        r_Payload[0] = 8'h48;  // 'H'
        r_Payload[1] = 8'h65;  // 'e'
        r_Payload[2] = 8'h6c;  // 'l'
        r_Payload[3] = 8'h6c;  // 'l'
        r_Payload[4] = 8'h6f;  // 'o'
    end

    initial begin
        r_Rsn     = 1'b0;
        r_TxValid = 1'b0;
        r_TxData  = '0;
        repeat (5) @(posedge r_Clk);
        r_Rsn = 1'b1;
        @(posedge r_Clk);

        // driver와 monitor를 병렬로 실행한다.
        fork
            begin : DRIVER_THREAD
                foreach (r_Payload[r_ByteIdx])
                    send_byte(r_Payload[r_ByteIdx]);
            end
            begin : MONITOR_THREAD
                foreach (r_Payload[r_ByteIdx])
                    recv_and_check(r_Payload[r_ByteIdx]);
            end
        join

        repeat (5 * CLKS_PER_BIT) @(posedge r_Clk);
        $finish;
    end

endmodule
