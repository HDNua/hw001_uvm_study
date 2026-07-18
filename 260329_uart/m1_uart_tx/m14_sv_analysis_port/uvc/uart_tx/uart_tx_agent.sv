// UART TX agent class.
//
// driver와 monitor 객체를 소유하며 actual 연결은 env가 monitor.ap에 수행한다.

class uart_tx_agent;
    uart_tx_driver  driver;
    uart_tx_monitor monitor;

    function new(
        virtual uart_tx_if vif,
        uart_tx_seq_item_port seq_item_port
    );
        driver  = new(vif, seq_item_port);
        monitor = new(vif);
    endfunction

    task run(input int num_bytes);
        fork
            driver.run(num_bytes);
            monitor.run(num_bytes);
        join
    endtask
endclass
