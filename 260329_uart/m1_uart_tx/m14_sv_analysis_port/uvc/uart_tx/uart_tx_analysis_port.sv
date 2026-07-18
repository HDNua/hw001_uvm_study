// 순수 SystemVerilog로 만든 analysis_port / analysis_imp bridge.
// 실제 UVM의 analysis port처럼 monitor는 subscriber를 직접 알지 않고 write()만 호출한다.

class uart_tx_analysis_imp;
    uart_tx_scoreboard scoreboard;

    function new(uart_tx_scoreboard scoreboard);
        this.scoreboard = scoreboard;
    endfunction

    function void write(input uart_tx_seq_item item);
        $display("[IMP] write item: 0x%02h", item.data);
        scoreboard.write(item);
    endfunction
endclass

class uart_tx_analysis_port;
    uart_tx_analysis_imp imp;

    function void connect(uart_tx_analysis_imp imp);
        this.imp = imp;
        $display("[AP] connected");
    endfunction

    function void write(input uart_tx_seq_item item);
        if (imp == null)
            $fatal(1, "[AP] analysis_port is not connected");

        $display("[AP] write item: 0x%02h", item.data);
        imp.write(item);
    endfunction
endclass
