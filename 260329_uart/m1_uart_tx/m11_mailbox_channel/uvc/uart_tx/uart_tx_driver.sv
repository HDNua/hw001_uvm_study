// TB_Top scope에 include되는 driver 역할 파일.
// sequencer mailbox에서 sequence item을 받아 그대로 interface에 구동한다.

task automatic uart_tx_driver(input int num_transfers);
    uart_tx_seq_item item;

    repeat (num_transfers) begin
        uart_tx_sequencer_get_item(item);
        $display("[DRV] driving item: 0x%02h", item.data);

        do @(posedge r_Clk); while (!I_UART_TxIf.w_TxReady);
        I_UART_TxIf.r_TxData  <= item.data;
        I_UART_TxIf.r_TxValid <= 1'b1;
        @(posedge r_Clk);
        I_UART_TxIf.r_TxValid <= 1'b0;
    end
endtask
