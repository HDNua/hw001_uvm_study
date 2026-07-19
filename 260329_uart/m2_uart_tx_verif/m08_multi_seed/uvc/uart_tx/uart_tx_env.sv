// 실제 UVM env가 component와 expected/actual analysis 경로를 조립한다.
class uart_tx_env extends uvm_env;
    uart_tx_agent      agent;
    uart_tx_scoreboard scoreboard;
    uart_tx_coverage   coverage;
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
        coverage   = uart_tx_coverage::type_id::create("coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        expected_ap.connect(scoreboard.expected_imp);
        agent.monitor.ap.connect(scoreboard.actual_imp);
        agent.driver.req_ap.connect(coverage.analysis_export);
        `uvm_info("ENV", "expected/actual/coverage analysis ports connected", UVM_LOW)
    endfunction
endclass
