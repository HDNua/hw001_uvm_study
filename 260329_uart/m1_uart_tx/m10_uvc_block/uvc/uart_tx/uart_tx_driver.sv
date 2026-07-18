// TB_Top scope에 include되는 driver 역할 파일.
// sequencer에서 raw data를 받아 sequence item으로 감싼 뒤 interface를 구동한다.

task automatic uart_tx_driver(input int num_transfers);
    uart_tx_seq_item item;
    logic [7:0]      r_Data;

    repeat (num_transfers) begin
        uart_tx_sequencer_get_data(r_Data);
        item = new(r_Data);
        $display("[DRV] driving item: 0x%02h", item.data);

        do @(posedge r_Clk); while (!I_UART_TxIf.w_TxReady);
        I_UART_TxIf.r_TxData  <= item.data;
        I_UART_TxIf.r_TxValid <= 1'b1;
        @(posedge r_Clk);
        I_UART_TxIf.r_TxValid <= 1'b0;
    end
endtask
