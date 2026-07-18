// UART TX driver class.
//
// m12와 달리 sequencer를 직접 알지 않고 seq_item_port API로 req를 받는다.
// 아직 실제 uvm_driver가 아닌 순수 SystemVerilog helper 구조다.

class uart_tx_driver;
    virtual uart_tx_if vif;
    uart_tx_seq_item_port seq_item_port;
    uart_tx_seq_item req;

    function new(
        virtual uart_tx_if vif,
        uart_tx_seq_item_port seq_item_port
    );
        this.vif           = vif;
        this.seq_item_port = seq_item_port;
    endfunction

    task run(input int num_transfers);
        repeat (num_transfers) begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_item(input uart_tx_seq_item item);
        $display("[DRV] driving req: 0x%02h", item.data);

        do @(posedge vif.i_Clk); while (!vif.w_TxReady);
        vif.r_TxData  <= item.data;
        vif.r_TxValid <= 1'b1;
        @(posedge vif.i_Clk);
        vif.r_TxValid <= 1'b0;
    endtask
endclass
