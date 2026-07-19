// 실제 UVM monitor.
// 전송 중 리셋이 오면 진행 중인 capture를 버리고 재동기화한다.

class uart_tx_monitor extends uvm_monitor;
    virtual uart_tx_if vif;
    uvm_analysis_port #(uart_tx_seq_item) ap;

    `uvm_component_utils(uart_tx_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual uart_tx_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "uart_tx_monitor requires virtual uart_tx_if")
    endfunction

    task run_phase(uvm_phase phase);
        logic [7:0] r_Captured;
        uart_tx_seq_item item;

        forever begin
            wait (vif.i_Rsn === 1'b1);
            @(posedge vif.i_Clk);

            forever begin
                // capture와 reset 감시를 경쟁시킨다.
                fork
                    begin : capture_frame
                        @(negedge vif.w_TxSerial);
                        repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge vif.i_Clk);

                        for (int r_BitIdx = 0; r_BitIdx < 8; r_BitIdx++) begin
                            r_Captured[r_BitIdx] = vif.w_TxSerial;
                            if (r_BitIdx < 7)
                                repeat (CLKS_PER_BIT) @(posedge vif.i_Clk);
                        end

                        repeat (CLKS_PER_BIT) @(posedge vif.i_Clk);
                        // 프로토콜 위반은 이 단계부터 error로 승격한다.
                        if (vif.w_TxSerial !== 1'b1)
                            `uvm_error("MON", "framing error: stop bit not high")
                    end
                    begin : watch_reset
                        @(negedge vif.i_Rsn);
                    end
                join_any
                disable fork;

                if (vif.i_Rsn !== 1'b1) begin
                    // 리셋으로 잘린 프레임은 publish하지 않는다.
                    `uvm_info("MON", "capture aborted by reset", UVM_LOW)
                    break;
                end

                item = uart_tx_seq_item::type_id::create("item", this);
                item.data = r_Captured;
                `uvm_info("MON", $sformatf("captured item: 0x%02h", item.data), UVM_LOW)
                ap.write(item);
            end
        end
    endtask
endclass
