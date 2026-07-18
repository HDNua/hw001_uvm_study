// TB_Top scope에 include되는 monitor 역할 파일.
// UART TX interface의 serial pin을 샘플링해 actual byte를 복원한다.

task automatic uart_tx_monitor(input int num_bytes);
    logic [7:0] r_Captured;

    repeat (num_bytes) begin
        @(negedge I_UART_TxIf.w_TxSerial);
        repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge r_Clk);

        for (int r_BitIdx = 0; r_BitIdx < 8; r_BitIdx++) begin
            r_Captured[r_BitIdx] = I_UART_TxIf.w_TxSerial;
            if (r_BitIdx < 7)
                repeat (CLKS_PER_BIT) @(posedge r_Clk);
        end

        repeat (CLKS_PER_BIT) @(posedge r_Clk);
        if (I_UART_TxIf.w_TxSerial !== 1'b1)
            $display("[MON] WARNING: framing error");

        $display("[MON] captured item: 0x%02h", r_Captured);
        uart_tx_scoreboard_write_actual(r_Captured);
    end
endtask
