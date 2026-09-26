// -----------------------------------------------------------------------------
// File        : axi4lite_driver.sv
// Description : UVM driver that converts axi4lite_transaction sequence items
//               into pin-level AXI4-Lite activity on the virtual interface.
//
//               Drives AW and W channels via two independent fork branches
//               (honoring aw_delay/w_delay) to exercise the DUT's
//               independent-channel-arrival support, and supports
//               programmable backpressure on BREADY/RREADY.
// -----------------------------------------------------------------------------

class axi4lite_driver extends uvm_driver #(axi4lite_transaction);

    `uvm_component_utils(axi4lite_driver)

    virtual axi4lite_if vif;
    axi4lite_agent_config cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(axi4lite_agent_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("DRV", "No agent config found for driver")
        vif = cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);
        reset_signals();
        wait (vif.ARESETn === 1'b1);
        forever begin
            axi4lite_transaction req;
            seq_item_port.get_next_item(req);
            req.start_time = $time;
            if (req.dir == axi4lite_transaction::AXI_WRITE)
                drive_write(req);
            else
                drive_read(req);
            req.end_time = $time;
            seq_item_port.item_done();
        end
    endtask

    task reset_signals();
        vif.drv_cb.AWADDR  <= '0;
        vif.drv_cb.AWPROT  <= '0;
        vif.drv_cb.AWVALID <= 1'b0;
        vif.drv_cb.WDATA   <= '0;
        vif.drv_cb.WSTRB   <= '0;
        vif.drv_cb.WVALID  <= 1'b0;
        vif.drv_cb.BREADY  <= 1'b0;
        vif.drv_cb.ARADDR  <= '0;
        vif.drv_cb.ARPROT  <= '0;
        vif.drv_cb.ARVALID <= 1'b0;
        vif.drv_cb.RREADY  <= 1'b0;
    endtask

    // ------------------------------------------------------------------
    // WRITE: drive AW and W as two independent processes so aw_delay and
    // w_delay can be honored separately, then handle the B response
    // (with optional BREADY backpressure).
    // ------------------------------------------------------------------
    task drive_write(axi4lite_transaction req);
        bit aw_done, w_done;
        aw_done = 0; w_done = 0;

        fork
            begin : aw_ch
                repeat (req.aw_delay) @(vif.drv_cb);
                vif.drv_cb.AWADDR  <= req.addr;
                vif.drv_cb.AWPROT  <= 3'b000;
                vif.drv_cb.AWVALID <= 1'b1;
                do begin
                    @(vif.drv_cb);
                end while (!vif.drv_cb.AWREADY);
                vif.drv_cb.AWVALID <= 1'b0;
                aw_done = 1;
            end
            begin : w_ch
                repeat (req.w_delay) @(vif.drv_cb);
                vif.drv_cb.WDATA  <= req.wdata;
                vif.drv_cb.WSTRB  <= req.wstrb;
                vif.drv_cb.WVALID <= 1'b1;
                do begin
                    @(vif.drv_cb);
                end while (!vif.drv_cb.WREADY);
                vif.drv_cb.WVALID <= 1'b0;
                w_done = 1;
            end
        join

        // Optional BREADY backpressure: hold BREADY low for
        // bready_delay cycles before sampling the response.
        repeat (req.bready_delay) @(vif.drv_cb);
        vif.drv_cb.BREADY <= 1'b1;
        do begin
            @(vif.drv_cb);
        end while (!vif.drv_cb.BVALID);
        req.bresp = vif.drv_cb.BRESP;
        @(vif.drv_cb);
        vif.drv_cb.BREADY <= 1'b0;
    endtask

    // ------------------------------------------------------------------
    // READ: drive AR, then optionally backpressure RREADY before
    // consuming RDATA/RRESP.
    // ------------------------------------------------------------------
    task drive_read(axi4lite_transaction req);
        vif.drv_cb.ARADDR  <= req.addr;
        vif.drv_cb.ARPROT  <= 3'b000;
        vif.drv_cb.ARVALID <= 1'b1;
        do begin
            @(vif.drv_cb);
        end while (!vif.drv_cb.ARREADY);
        vif.drv_cb.ARVALID <= 1'b0;

        repeat (req.rready_delay) @(vif.drv_cb);
        vif.drv_cb.RREADY <= 1'b1;
        do begin
            @(vif.drv_cb);
        end while (!vif.drv_cb.RVALID);
        req.rdata = vif.drv_cb.RDATA;
        req.rresp = vif.drv_cb.RRESP;
        @(vif.drv_cb);
        vif.drv_cb.RREADY <= 1'b0;
    endtask

endclass : axi4lite_driver
