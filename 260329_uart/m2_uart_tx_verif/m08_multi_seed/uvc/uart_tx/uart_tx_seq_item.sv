// rand 필드와 constraint를 가진 sequence item.
// corner 단계에서 busy 중 valid 주입 정보가 추가된다.
class uart_tx_seq_item extends uvm_sequence_item;
    rand logic [7:0] data;
    rand int unsigned idle_gap;   // 구동 전 대기할 idle clock cycle 수

    // busy 중 valid 주입: sequence의 corner mode가 설정한다.
    // 주입된 busy_data는 DUT가 무시해야 하며 expected 경로에 실리지 않는다.
    bit              inject_busy_valid = 1'b0;
    rand logic [7:0] busy_data;

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
        return $sformatf("data=0x%02h gap=%0d busy_valid=%0b", data, idle_gap, inject_busy_valid);
    endfunction
endclass
