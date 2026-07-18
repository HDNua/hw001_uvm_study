// TB_Top scope에 include되는 agent 역할 파일.
// 한 UART TX interface의 driver와 monitor를 병렬 실행한다.

task automatic uart_tx_agent(input int num_bytes);
    fork
        begin : DRIVER_THREAD
            uart_tx_driver(num_bytes);
        end
        begin : MONITOR_THREAD
            uart_tx_monitor(num_bytes);
        end
    join
endtask
