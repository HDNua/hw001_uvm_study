// UART TX monitor class.
//
// virtual interface의 serial pin을 샘플링해 actual item을 만든다.

class uart_tx_monitor;
    virtual uart_tx_if vif;
    mailbox #(uart_tx_seq_item) mon_mbx;

    function new(
        virtual uart_tx_if vif,
        mailbox #(uart_tx_seq_item) mon_mbx
    );
        this.vif     = vif;
        this.mon_mbx = mon_mbx;
    endfunction

    task run(input int num_bytes);
        logic [7:0]    r_Captured;
        uart_tx_seq_item item;

        repeat (num_bytes) begin
            @(negedge vif.w_TxSerial);
            repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge vif.i_Clk);

            for (int r_BitIdx = 0; r_BitIdx < 8; r_BitIdx++) begin
                r_Captured[r_BitIdx] = vif.w_TxSerial;
                if (r_BitIdx < 7)
                    repeat (CLKS_PER_BIT) @(posedge vif.i_Clk);
            end

            repeat (CLKS_PER_BIT) @(posedge vif.i_Clk);
            if (vif.w_TxSerial !== 1'b1)
                $display("[MON] WARNING: framing error");

            item = new(r_Captured);
            mon_mbx.put(item);
            $display("[MON] captured item: 0x%02h", item.data);
        end
    endtask
endclass
