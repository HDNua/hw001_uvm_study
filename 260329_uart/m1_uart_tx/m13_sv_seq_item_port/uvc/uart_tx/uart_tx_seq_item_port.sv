// 실제 UVM library 없이 driver가 바라보는 seq_item_port API 모양을 만든다.
// item 보관과 blocking 대기는 내부 sequencer mailbox가 계속 담당한다.

class uart_tx_seq_item_port;
    uart_tx_sequencer sequencer;

    function new(uart_tx_sequencer sequencer);
        this.sequencer = sequencer;
    endfunction

    task get_next_item(output uart_tx_seq_item item);
        sequencer.get_next_item(item);
        $display("[PORT] get_next_item req: 0x%02h", item.data);
    endtask

    task item_done();
        sequencer.item_done();
        $display("[PORT] item_done");
    endtask
endclass
