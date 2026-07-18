// UART TX driver class.
//
// m11의 driver task를 class로 올리고 virtual interface로 DUT pin을 구동한다.
// 12단계에서는 driver가 sequencer에서 item을 blocking get으로 받는다.
// 13단계에서는 이 입력 경로가 seq_item_port.get_next_item(req) 모양으로 바뀐다.

class uart_tx_driver;
    virtual uart_tx_if vif;
    uart_tx_sequencer sequencer;

    function new(
        virtual uart_tx_if vif,
        uart_tx_sequencer sequencer
    );
        this.vif       = vif;
        this.sequencer = sequencer;
    endfunction

    task run(input int num_transfers);
        uart_tx_seq_item item;

        repeat (num_transfers) begin
            sequencer.get_item(item);
            drive_item(item);
        end
    endtask

    task drive_item(input uart_tx_seq_item item);
        $display("[DRV] driving item: 0x%02h", item.data);

        do @(posedge vif.i_Clk); while (!vif.w_TxReady);
        vif.r_TxData  <= item.data;
        vif.r_TxValid <= 1'b1;
        @(posedge vif.i_Clk);
        vif.r_TxValid <= 1'b0;
    endtask
endclass
