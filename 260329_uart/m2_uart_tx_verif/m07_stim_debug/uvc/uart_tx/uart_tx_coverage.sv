// functional coverage subscriber.
// driver가 실제로 구동한 request item을 받아 "무엇을 얼마나 쳤는지"를 계량한다.
class uart_tx_coverage extends uvm_subscriber #(uart_tx_seq_item);
    uart_tx_seq_item item;

    `uvm_component_utils(uart_tx_coverage)

    covergroup cg_uart_tx;
        option.per_instance = 1;

        // 데이터 값: 경계값과 구간 bins.
        cp_data: coverpoint item.data {
            bins zero       = {8'h00};
            bins ones       = {8'hff};
            bins alt_a      = {8'h55};
            bins alt_b      = {8'haa};
            bins low_range  = {[8'h01 : 8'h3f]};
            bins mid_range  = {[8'h40 : 8'hbf]};
            bins high_range = {[8'hc0 : 8'hfe]};
        }

        // byte 사이 간격: back-to-back과 bit 시간 단위 구간 bins.
        cp_gap: coverpoint item.idle_gap {
            bins zero_gap  = {0};
            bins short_gap = {[1 : CLKS_PER_BIT - 1]};
            bins mid_gap   = {[CLKS_PER_BIT : 2 * CLKS_PER_BIT - 1]};
            bins long_gap  = {[2 * CLKS_PER_BIT : 3 * CLKS_PER_BIT]};
        }

        // busy 중 valid 주입 여부.
        cp_busy: coverpoint item.inject_busy_valid {
            bins off = {1'b0};
            bins on  = {1'b1};
        }

        // 값과 시간축의 조합.
        cx_data_gap: cross cp_data, cp_gap;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_uart_tx = new();
    endfunction

    function void write(uart_tx_seq_item t);
        item = t;
        cg_uart_tx.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("COV", $sformatf(
            "UART_TX_VERIF_COVERAGE data=%.1f%% gap=%.1f%% busy=%.1f%% cross=%.1f%% total=%.1f%%",
            cg_uart_tx.cp_data.get_coverage(),
            cg_uart_tx.cp_gap.get_coverage(),
            cg_uart_tx.cp_busy.get_coverage(),
            cg_uart_tx.cx_data_gap.get_coverage(),
            cg_uart_tx.get_coverage()), UVM_LOW)
    endfunction
endclass
