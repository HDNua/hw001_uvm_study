// TB_Top scope에 include되는 sequence 역할 파일.
// 같은 payload로 driver item과 expected item을 만들어 각각의 mailbox에 보낸다.

task automatic uart_tx_mail_current_payload();
    uart_tx_seq_item driver_item;
    uart_tx_seq_item expected_item;

    foreach (r_Payload[r_ByteIdx]) begin
        driver_item   = new(r_Payload[r_ByteIdx]);
        expected_item = new(r_Payload[r_ByteIdx]);
        uart_tx_sequencer_put_item(driver_item);
        uart_tx_scoreboard_put_expected(expected_item);
        $display("[SEQ] mailed item/expected: 0x%02h", driver_item.data);
    end
endtask

task automatic uart_tx_smoke_sequence();
    $display("[SEQ] smoke_sequence start");
    uart_tx_mail_current_payload();
endtask

task automatic uart_tx_pattern_sequence();
    $display("[SEQ] pattern_sequence start");
    uart_tx_mail_current_payload();
endtask

task automatic uart_tx_random_sequence();
    $display("[SEQ] random_sequence start");
    uart_tx_mail_current_payload();
endtask
