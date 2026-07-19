// 실제 UVM driver.
// corner 단계에서 전송 중(o_TxReady=0) valid 주입 구동이 추가된다.

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
        `uvm_info("DRV", $sformatf("driving req: 0x%02h gap=%0d busy_valid=%0b", item.data, item.idle_gap, item.inject_busy_valid), UVM_LOW)

        // 랜덤 idle 간격으로 byte 사이 시간축을 흔든다.
        repeat (item.idle_gap) @(posedge vif.i_Clk);
        do @(posedge vif.i_Clk); while (!vif.w_TxReady);
        vif.r_TxData  <= item.data;
        vif.r_TxValid <= 1'b1;
        @(posedge vif.i_Clk);
        vif.r_TxValid <= 1'b0;

        if (item.inject_busy_valid)
            inject_busy_valid(item.busy_data);
    endtask

    // 전송 중(o_TxReady=0)에 valid를 다시 올린다.
    // 핸드셰이크 규약상 DUT는 이 요청을 조용히 무시해야 한다.
    task inject_busy_valid(input logic [7:0] busy_data);
        wait (vif.w_TxReady === 1'b0);
        @(posedge vif.i_Clk);
        vif.r_TxData  <= busy_data;
        vif.r_TxValid <= 1'b1;
        @(posedge vif.i_Clk);
        vif.r_TxValid <= 1'b0;
        `uvm_info("DRV", $sformatf("busy valid injected: 0x%02h (must be ignored)", busy_data), UVM_LOW)
    endtask
endclass
