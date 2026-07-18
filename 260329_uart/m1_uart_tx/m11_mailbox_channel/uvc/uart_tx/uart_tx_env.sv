// TB_Top scope에 include되는 env 역할 파일.
// agent와 scoreboard를 병렬 실행하는 UART TX 검증 환경이다.

task automatic uart_tx_env(input int num_bytes);
    fork
        begin : AGENT_THREAD
            uart_tx_agent(num_bytes);
        end
        begin : SCOREBOARD_THREAD
            uart_tx_scoreboard_run(num_bytes);
        end
    join
endtask
