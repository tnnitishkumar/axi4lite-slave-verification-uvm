// -----------------------------------------------------------------------------
// File        : axi4lite_coverage.sv
// Description : Functional coverage collector. Subscribes to the monitor's
//               analysis port and samples covergroups for:
//                 - read vs write direction
//                 - register address hit (each of NUM_REGS regs)
//                 - WSTRB patterns
//                 - response codes (OKAY/SLVERR) per direction
//                 - independent AW/W arrival ordering (write)
//                 - backpressure delay buckets (bready/rready)
//                 - direction x response cross
// -----------------------------------------------------------------------------

class axi4lite_coverage extends uvm_subscriber #(axi4lite_transaction);

    `uvm_component_utils(axi4lite_coverage)

    axi4lite_transaction txn;

    covergroup cg_transaction with function sample(axi4lite_transaction t);
        option.per_instance = 1;

        cp_dir : coverpoint t.dir {
            bins wr = {axi4lite_transaction::AXI_WRITE};
            bins rd = {axi4lite_transaction::AXI_READ};
        }

        cp_reg_addr : coverpoint (t.addr >> 2) {
            bins reg_idx[axi4lite_pkg::NUM_REGS] = {[0:axi4lite_pkg::NUM_REGS-1]};
            bins out_of_range = default;
        }

        cp_wstrb : coverpoint t.wstrb iff (t.dir == axi4lite_transaction::AXI_WRITE) {
            bins all_bytes   = {4'b1111};
            bins byte0_only  = {4'b0001};
            bins byte1_only  = {4'b0010};
            bins byte2_only  = {4'b0100};
            bins byte3_only  = {4'b1000};
            bins lower_half  = {4'b0011};
            bins upper_half  = {4'b1100};
            bins other_mixed = default;
        }

        cp_bresp : coverpoint t.bresp iff (t.dir == axi4lite_transaction::AXI_WRITE) {
            bins okay   = {2'b00};
            bins slverr = {2'b10};
        }

        cp_rresp : coverpoint t.rresp iff (t.dir == axi4lite_transaction::AXI_READ) {
            bins okay   = {2'b00};
            bins slverr = {2'b10};
        }

        // Independent AW/W arrival ordering: which channel's handshake
        // completed first. The monitor reuses aw_delay/w_delay to carry
        // the *cycle number* each channel's handshake completed on.
        cp_aw_w_order : coverpoint (t.aw_delay == t.w_delay ? 2'd0 :
                                     (t.aw_delay < t.w_delay ? 2'd1 : 2'd2))
                        iff (t.dir == axi4lite_transaction::AXI_WRITE) {
            bins same_cycle = {2'd0};
            bins aw_first   = {2'd1};
            bins w_first    = {2'd2};
        }

        cp_bready_delay : coverpoint t.bready_delay iff (t.dir == axi4lite_transaction::AXI_WRITE) {
            bins none      = {0};
            bins short_bp  = {[1:2]};
            bins long_bp   = {[3:$]};
        }

        cp_rready_delay : coverpoint t.rready_delay iff (t.dir == axi4lite_transaction::AXI_READ) {
            bins none      = {0};
            bins short_bp  = {[1:2]};
            bins long_bp   = {[3:$]};
        }

        cx_dir_resp : cross cp_dir, cp_bresp, cp_rresp;

    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_transaction = new();
    endfunction

    function void write(axi4lite_transaction t);
        txn = t;
        cg_transaction.sample(t);
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("COV", $sformatf(
            "Functional coverage (cg_transaction) = %0.2f%%", cg_transaction.get_coverage()),
            UVM_NONE)
    endfunction

endclass : axi4lite_coverage
