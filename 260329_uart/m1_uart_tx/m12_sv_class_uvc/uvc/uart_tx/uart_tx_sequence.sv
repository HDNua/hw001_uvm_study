// UART TX sequence class.
//
// test가 고른 payload로 driver item과 expected item을 만들고,
// m11과 같은 두 mailbox 경로에 각각 전달한다.

class uart_tx_sequence;
    uart_tx_sequencer sequencer;
    mailbox #(uart_tx_seq_item) exp_mbx;

    function new(
        uart_tx_sequencer sequencer,
        mailbox #(uart_tx_seq_item) exp_mbx
    );
        this.sequencer = sequencer;
        this.exp_mbx   = exp_mbx;
    endfunction

    task send_payload(
        input string sequence_name,
        input logic [7:0] payload [0:UART_TX_NUM_BYTES-1]
    );
        uart_tx_seq_item driver_item;
        uart_tx_seq_item expected_item;

        $display("[SEQ] %s start", sequence_name);
        foreach (payload[r_ByteIdx]) begin
            driver_item   = new(payload[r_ByteIdx]);
            expected_item = new(payload[r_ByteIdx]);
            sequencer.put_item(driver_item);
            exp_mbx.put(expected_item);
            $display("[SEQ] class item/expected: 0x%02h", driver_item.data);
        end
    endtask
endclass
