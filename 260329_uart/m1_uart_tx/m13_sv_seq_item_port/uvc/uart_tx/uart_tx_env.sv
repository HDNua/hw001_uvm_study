// UART TX env class.
//
// agent와 scoreboard 객체를 소유하는 상위 환경이다.
// test는 sequence를 시작하고, env는 실제 구동/감시/비교 루프를 책임진다.

class uart_tx_env;
    uart_tx_agent      agent;
    uart_tx_scoreboard scoreboard;

    function new(
        virtual uart_tx_if vif,
        uart_tx_seq_item_port seq_item_port,
        mailbox #(uart_tx_seq_item) exp_mbx,
        mailbox #(uart_tx_seq_item) mon_mbx
    );
        agent      = new(vif, seq_item_port, mon_mbx);
        scoreboard = new(exp_mbx, mon_mbx);
    endfunction

    task run(input int num_bytes);
        fork
            agent.run(num_bytes);
            scoreboard.run(num_bytes);
        join
    endtask
endclass
