// UART TX sequencer class.
//
// m11의 sequencer 역할 task와 driver mailbox를 한 객체 안으로 옮긴다.
// sequence와 driver는 test가 만든 동일한 sequencer handle을 공유한다.

class uart_tx_sequencer;
    mailbox #(uart_tx_seq_item) drv_mbx;

    function new();
        drv_mbx = new();
    endfunction

    task reset();
        uart_tx_seq_item ignored;

        while (drv_mbx.try_get(ignored)) begin
        end
    endtask

    task put_item(input uart_tx_seq_item item);
        drv_mbx.put(item);
        $display("[SEQR] put item: 0x%02h", item.data);
    endtask

    task get_item(output uart_tx_seq_item item);
        drv_mbx.get(item);
        $display("[SEQR] get item: 0x%02h", item.data);
    endtask
endclass
