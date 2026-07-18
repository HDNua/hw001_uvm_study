// UART TX agent class.
//
// driver와 monitor 객체를 소유하고 함께 실행한다.

class uart_tx_agent;
    uart_tx_driver  driver;
    uart_tx_monitor monitor;

    function new(
        virtual uart_tx_if vif,
        uart_tx_sequencer sequencer,
        mailbox #(uart_tx_seq_item) mon_mbx
    );
        driver  = new(vif, sequencer);
        monitor = new(vif, mon_mbx);
    endfunction

    task run(input int num_bytes);
        fork
            driver.run(num_bytes);
            monitor.run(num_bytes);
        join
    endtask
endclass
