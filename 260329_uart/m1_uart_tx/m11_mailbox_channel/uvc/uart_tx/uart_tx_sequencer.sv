// TB_Top scope에 include되는 sequencer 역할 파일.
// sequence item mailbox로 producer와 consumer를 연결한다.

mailbox #(uart_tx_seq_item) r_DrvMbx = new();

task automatic uart_tx_sequencer_reset();
    uart_tx_seq_item ignored;

    while (r_DrvMbx.try_get(ignored)) begin
    end
endtask

task automatic uart_tx_sequencer_put_item(input uart_tx_seq_item item);
    r_DrvMbx.put(item);
    $display("[SEQR] put item: 0x%02h", item.data);
endtask

task automatic uart_tx_sequencer_get_item(output uart_tx_seq_item item);
    // mailbox가 비어 있으면 item이 도착할 때까지 자동으로 block된다.
    r_DrvMbx.get(item);
    $display("[SEQR] get item: 0x%02h", item.data);
endtask
