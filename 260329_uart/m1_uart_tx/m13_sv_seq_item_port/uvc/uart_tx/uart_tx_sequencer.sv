// UART TX sequencer class.
//
// m12의 item mailbox를 유지하되 driver에는 seq_item_port API를 노출한다.

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

    task get_next_item(output uart_tx_seq_item item);
        drv_mbx.get(item);
        $display("[SEQR] get_next_item: 0x%02h", item.data);
    endtask

    task item_done();
        // 이 순수 SV bridge에서는 mailbox get으로 전달이 끝났으므로 별도 handshake는 없다.
        $display("[SEQR] item_done");
    endtask
endclass
