// -----------------------------------------------------------------------------
// File        : axi4lite_monitor.sv
// Description : Passive UVM monitor. Watches the AXI4-Lite bus and publishes
//               one axi4lite_transaction per completed write (AW+W+B) or
//               read (AR+R) to two analysis ports: one for the scoreboard,
//               one for the coverage collector. Also tracks independent
//               AW/W arrival timing and backpressure cycle counts for
//               coverage.
// -----------------------------------------------------------------------------

class axi4lite_monitor extends uvm_monitor;

    `uvm_component_utils(axi4lite_monitor)

    virtual axi4lite_if vif;
    axi4lite_agent_config cfg;

    uvm_analysis_port #(axi4lite_transaction) item_collected_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(axi4lite_agent_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("MON", "No agent config found for monitor")
        vif = cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);
        fork
            watch_writes();
            watch_reads();
        join
    endtask

    // ------------------------------------------------------------------
    // Write channel observation: independently track when AW and W each
    // complete their handshake (they may land on different cycles), then
    // wait for the B handshake to close out the transaction.
    // ------------------------------------------------------------------
    task watch_writes();
        forever begin
            bit aw_seen, w_seen;
            bit [31:0] cap_addr;
            bit [31:0] cap_data;
            bit [3:0]  cap_strb;
            int unsigned aw_cycle, w_cycle, cur_cycle;
            axi4lite_transaction txn;

            aw_seen = 0; w_seen = 0; cur_cycle = 0;

            // Wait until at least one of AW/W handshakes; keep counting
            // cycles so we can report how far apart the two arrived.
            while (!(aw_seen && w_seen)) begin
                @(vif.mon_cb);
                cur_cycle++;
                if (!aw_seen && vif.mon_cb.AWVALID && vif.mon_cb.AWREADY) begin
                    cap_addr = vif.mon_cb.AWADDR;
                    aw_seen  = 1;
                    aw_cycle = cur_cycle;
                end
                if (!w_seen && vif.mon_cb.WVALID && vif.mon_cb.WREADY) begin
                    cap_data = vif.mon_cb.WDATA;
                    cap_strb = vif.mon_cb.WSTRB;
                    w_seen   = 1;
                    w_cycle  = cur_cycle;
                end
            end

            // Wait for the write response
            do begin
                @(vif.mon_cb);
            end while (!vif.mon_cb.BVALID);
            // Response is only truly "taken" once BREADY is also high;
            // sample resp now (stable until BREADY per protocol), then
            // wait for the actual handshake to close the transaction.
            txn = axi4lite_transaction::type_id::create("mon_wr_txn");
            txn.dir    = axi4lite_transaction::AXI_WRITE;
            txn.addr   = cap_addr;
            txn.wdata  = cap_data;
            txn.wstrb  = cap_strb;
            txn.bresp  = vif.mon_cb.BRESP;
            txn.aw_delay = aw_cycle;
            txn.w_delay  = w_cycle;

            while (!(vif.mon_cb.BVALID && vif.mon_cb.BREADY)) @(vif.mon_cb);

            `uvm_info("MON", $sformatf("Observed %s", txn.convert2string()), UVM_HIGH)
            item_collected_port.write(txn);
        end
    endtask

    // ------------------------------------------------------------------
    // Read channel observation
    // ------------------------------------------------------------------
    task watch_reads();
        forever begin
            bit [31:0] cap_addr;
            axi4lite_transaction txn;

            do begin
                @(vif.mon_cb);
            end while (!(vif.mon_cb.ARVALID && vif.mon_cb.ARREADY));
            cap_addr = vif.mon_cb.ARADDR;

            do begin
                @(vif.mon_cb);
            end while (!vif.mon_cb.RVALID);

            txn = axi4lite_transaction::type_id::create("mon_rd_txn");
            txn.dir   = axi4lite_transaction::AXI_READ;
            txn.addr  = cap_addr;
            txn.rdata = vif.mon_cb.RDATA;
            txn.rresp = vif.mon_cb.RRESP;

            while (!(vif.mon_cb.RVALID && vif.mon_cb.RREADY)) @(vif.mon_cb);

            `uvm_info("MON", $sformatf("Observed %s", txn.convert2string()), UVM_HIGH)
            item_collected_port.write(txn);
        end
    endtask

endclass : axi4lite_monitor
