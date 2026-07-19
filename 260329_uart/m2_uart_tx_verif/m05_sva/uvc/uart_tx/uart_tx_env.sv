// 실제 UVM env가 component와 expected/actual analysis 경로를 조립한다.
class uart_tx_env extends uvm_env;
    uart_tx_agent      agent;
    uart_tx_scoreboard scoreboard;
    uvm_analysis_port #(uart_tx_seq_item) expected_ap;

    `uvm_component_utils(uart_tx_env)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        expected_ap = new("expected_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent      = uart_tx_agent::type_id::create("agent", this);
        scoreboard = uart_tx_scoreboard::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        expected_ap.connect(scoreboard.expected_imp);
        agent.monitor.ap.connect(scoreboard.actual_imp);
        `uvm_info("ENV", "expected/actual analysis ports connected", UVM_LOW)
    endfunction
endclass
