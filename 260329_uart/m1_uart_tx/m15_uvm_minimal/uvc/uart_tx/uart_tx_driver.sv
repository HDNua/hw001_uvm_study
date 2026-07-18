// 실제 UVM driver.
// m13~m14에서 연습한 get_next_item(req) / item_done()이 내장 port로 바뀐다.

class uart_tx_driver extends uvm_driver #(uart_tx_seq_item);
    virtual uart_tx_if vif;

    `uvm_component_utils(uart_tx_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual uart_tx_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "uart_tx_driver requires virtual uart_tx_if")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_item(input uart_tx_seq_item item);
        `uvm_info("DRV", $sformatf("driving req: 0x%02h", item.data), UVM_LOW)

        do @(posedge vif.i_Clk); while (!vif.w_TxReady);
        vif.r_TxData  <= item.data;
        vif.r_TxValid <= 1'b1;
        @(posedge vif.i_Clk);
        vif.r_TxValid <= 1'b0;
    endtask
endclass
