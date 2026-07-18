// TB_Top scope에 include되는 sequence 역할 파일.
// payload를 sequence item으로 감싼 뒤 raw data를 sequencer와 expected에 분배한다.

task automatic uart_tx_queue_current_payload();
    uart_tx_seq_item item;

    foreach (r_Payload[r_ByteIdx]) begin
        item = new(r_Payload[r_ByteIdx]);
        uart_tx_sequencer_put_data(item.data);
        uart_tx_scoreboard_push_expected(item.data);
        $display("[SEQ] queued item/expected: 0x%02h", item.data);
    end
endtask

task automatic uart_tx_smoke_sequence();
    $display("[SEQ] smoke_sequence start");
    uart_tx_queue_current_payload();
endtask

task automatic uart_tx_pattern_sequence();
    $display("[SEQ] pattern_sequence start");
    uart_tx_queue_current_payload();
endtask

task automatic uart_tx_random_sequence();
    $display("[SEQ] random_sequence start");
    uart_tx_queue_current_payload();
endtask
