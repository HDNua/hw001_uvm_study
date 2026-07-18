`timescale 1ns/1ps

module TB_Top;

    localparam int CLK_FREQ     = 50_000_000;
    localparam int BAUD_RATE    = 115_200;
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

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
    // 테스트
    // -------------------------------------------------------------------------
    logic [7:0] r_Captured;

    initial begin
        // 리셋
        r_Rsn      = 1'b0;
        r_TxValid  = 1'b0;
        r_TxData   = '0;
        r_Captured = '0;
        repeat (5) @(posedge r_Clk);
        r_Rsn = 1'b1;
        @(posedge r_Clk);

        // 전송 요청
        // CPU 쪽 출력 레지스터처럼 상승 엣지에서 요청을 등록한다.
        // DUT는 다음 상승 엣지에서 이 요청을 샘플링한다.
        do @(posedge r_Clk); while (!w_TxReady);
        r_TxData  <= 8'h48;   // 'H'
        r_TxValid <= 1'b1;
        @(posedge r_Clk);
        r_TxValid <= 1'b0;

        // 수신 및 직접 모니터링
        // start bit의 하강 엣지를 포착한다.
        @(negedge w_TxSerial);

        // 1.5 baud 후 D0 중앙에서 샘플링한다.
        repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge r_Clk);

        // 8비트를 LSB부터 샘플링한다.
        for (int r_BitIdx = 0; r_BitIdx < 8; r_BitIdx++) begin
            r_Captured[r_BitIdx] = w_TxSerial;
            if (r_BitIdx < 7)
                repeat (CLKS_PER_BIT) @(posedge r_Clk);
        end

        // 결과 확인
        if (r_Captured === 8'h48) begin
            $display("PASS: captured=0x%02h", r_Captured);
        end else begin
            $fatal(1, "FAIL: expected=0x48 captured=0x%02h", r_Captured);
        end

        repeat (CLKS_PER_BIT) @(posedge r_Clk);
        $finish;
    end

endmodule
