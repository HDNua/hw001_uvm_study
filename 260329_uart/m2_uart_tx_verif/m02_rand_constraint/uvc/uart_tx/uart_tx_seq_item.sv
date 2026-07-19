// rand 필드와 constraint를 가진 sequence item.
// 자극 값의 범위와 분포를 item constraint가 문서화한다.
class uart_tx_seq_item extends uvm_sequence_item;
    rand logic [7:0] data;
    rand int unsigned idle_gap;   // 구동 전 대기할 idle clock cycle 수

    // 경계값(0x00, 0xff)이 더 자주 나오게 가중치를 둔다.
    constraint c_data_dist {
        data dist { 8'h00 := 2, 8'hff := 2, [8'h01 : 8'hfe] :/ 12 };
    }

    // byte 사이 간격은 0에서 3 bit 시간까지 흔든다.
    constraint c_idle_gap {
        idle_gap inside {[0 : 3 * CLKS_PER_BIT]};
    }

    `uvm_object_utils(uart_tx_seq_item)

    function new(string name = "uart_tx_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("data=0x%02h gap=%0d", data, idle_gap);
    endfunction
endclass
