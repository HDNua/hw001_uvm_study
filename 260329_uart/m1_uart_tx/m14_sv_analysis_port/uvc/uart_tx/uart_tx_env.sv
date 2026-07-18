// UART TX env class.
//
// monitor analysis_port와 scoreboard analysis_imp를 constructor에서 연결한다.

class uart_tx_env;
    uart_tx_agent        agent;
    uart_tx_scoreboard   scoreboard;
    uart_tx_analysis_imp scoreboard_imp;

    function new(
        virtual uart_tx_if vif,
        uart_tx_seq_item_port seq_item_port,
        mailbox #(uart_tx_seq_item) exp_mbx
    );
        agent          = new(vif, seq_item_port);
        scoreboard     = new(exp_mbx);
        scoreboard_imp = new(scoreboard);

        agent.monitor.ap.connect(scoreboard_imp);
    endfunction

    task run(input int num_bytes);
        fork
            agent.run(num_bytes);
            scoreboard.run_expected(num_bytes);
        join
    endtask
endclass
