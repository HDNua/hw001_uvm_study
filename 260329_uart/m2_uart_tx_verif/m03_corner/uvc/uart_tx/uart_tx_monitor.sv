// 실제 UVM monitor.
// m14에서 흉내 낸 analysis_port.write()를 UVM TLM port로 전환한다.

class uart_tx_monitor extends uvm_monitor;
    virtual uart_tx_if vif;
    uvm_analysis_port #(uart_tx_seq_item) ap;

    `uvm_component_utils(uart_tx_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual uart_tx_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "uart_tx_monitor requires virtual uart_tx_if")
    endfunction

    task run_phase(uvm_phase phase);
        logic [7:0] r_Captured;
        uart_tx_seq_item item;

        wait (vif.i_Rsn === 1'b1);
        @(posedge vif.i_Clk);

        forever begin
            @(negedge vif.w_TxSerial);
            repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge vif.i_Clk);

            for (int r_BitIdx = 0; r_BitIdx < 8; r_BitIdx++) begin
                r_Captured[r_BitIdx] = vif.w_TxSerial;
                if (r_BitIdx < 7)
                    repeat (CLKS_PER_BIT) @(posedge vif.i_Clk);
            end

            repeat (CLKS_PER_BIT) @(posedge vif.i_Clk);
            if (vif.w_TxSerial !== 1'b1)
                `uvm_warning("MON", "framing error")

            item = uart_tx_seq_item::type_id::create("item", this);
            item.data = r_Captured;
            `uvm_info("MON", $sformatf("captured item: 0x%02h", item.data), UVM_LOW)
            ap.write(item);
        end
    endtask
endclass
