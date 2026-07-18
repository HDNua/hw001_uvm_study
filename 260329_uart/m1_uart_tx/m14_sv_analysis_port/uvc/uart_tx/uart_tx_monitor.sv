// UART TX monitor class.
//
// m13의 actual mailbox 대신 analysis_port.write()로 관측 item을 내보낸다.

class uart_tx_monitor;
    virtual uart_tx_if vif;
    uart_tx_analysis_port ap;

    function new(virtual uart_tx_if vif);
        this.vif = vif;
        ap = new();
    endfunction

    task run(input int num_bytes);
        logic [7:0] r_Captured;
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
            $display("[MON] captured item: 0x%02h", item.data);
            ap.write(item);
        end
    endtask
endclass
