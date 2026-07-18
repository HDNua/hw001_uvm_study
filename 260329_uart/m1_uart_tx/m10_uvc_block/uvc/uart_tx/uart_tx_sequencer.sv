// TB_Top scope에 include되는 sequencer 역할 파일.
// raw byte queue를 put/get API로 감싸 producer와 consumer를 분리한다.

logic [7:0] r_SeqrQ [$];
event       e_SeqrItemReady;

task automatic uart_tx_sequencer_reset();
    r_SeqrQ.delete();
endtask

task automatic uart_tx_sequencer_put_data(input logic [7:0] data);
    r_SeqrQ.push_back(data);
    -> e_SeqrItemReady;
    $display("[SEQR] put data: 0x%02h", data);
endtask

task automatic uart_tx_sequencer_get_data(output logic [7:0] data);
    while (r_SeqrQ.size() == 0)
        @(e_SeqrItemReady);

    data = r_SeqrQ.pop_front();
    $display("[SEQR] get data: 0x%02h", data);
endtask
