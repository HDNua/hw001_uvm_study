// TB_Top scope에 include되는 monitor 역할 파일.
// 복원한 actual byte를 sequence item으로 감싸 scoreboard mailbox에 보낸다.

task automatic uart_tx_monitor(input int num_bytes);
    logic [7:0]    r_Captured;
    uart_tx_seq_item item;

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

        item = new(r_Captured);
        $display("[MON] captured item: 0x%02h", item.data);
        uart_tx_scoreboard_write_actual(item);
    end
endtask
