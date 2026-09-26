// -----------------------------------------------------------------------------
// File        : axi4lite_scoreboard.sv
// Description : Reference-model scoreboard. Maintains a shadow copy of the
//               DUT's register file, applies observed WRITE transactions to
//               it (respecting WSTRB byte enables and address validity),
//               and checks observed READ transactions (both RDATA and
//               RRESP) plus WRITE responses (BRESP) against expectation.
// -----------------------------------------------------------------------------

class axi4lite_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(axi4lite_scoreboard)

    uvm_analysis_imp #(axi4lite_transaction, axi4lite_scoreboard) item_export;

    // Shadow register file - mirrors the DUT's regfile[0:NUM_REGS-1]
    bit [31:0] shadow_regs [0:axi4lite_pkg::NUM_REGS-1];

    int unsigned num_writes_checked;
    int unsigned num_reads_checked;
    int unsigned num_errors;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_export = new("item_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        foreach (shadow_regs[i]) shadow_regs[i] = '0;
    endfunction

    // Called by the monitor's analysis port for every completed
    // write or read transaction, in the order they complete on the bus.
    function void write(axi4lite_transaction t);
        if (t.dir == axi4lite_transaction::AXI_WRITE)
            handle_write(t);
        else
            handle_read(t);
    endfunction

    function bit addr_valid(bit [31:0] addr);
        addr_valid = (addr[1:0] == 2'b00) &&
                     ((addr >> 2) < axi4lite_pkg::NUM_REGS);
    endfunction

    function void handle_write(axi4lite_transaction t);
        bit expect_okay;
        num_writes_checked++;
        expect_okay = addr_valid(t.addr);

        if (expect_okay && t.bresp != 2'b00) begin
            `uvm_error("SCB", $sformatf(
                "WRITE addr=0x%08h expected OKAY but got BRESP=%0d", t.addr, t.bresp))
            num_errors++;
        end else if (!expect_okay && t.bresp != 2'b10) begin
            `uvm_error("SCB", $sformatf(
                "WRITE addr=0x%08h (out of range/unaligned) expected SLVERR but got BRESP=%0d",
                t.addr, t.bresp))
            num_errors++;
        end

        if (expect_okay) begin
            int idx = t.addr >> 2;
            for (int b = 0; b < 4; b++) begin
                if (t.wstrb[b]) shadow_regs[idx][b*8 +: 8] = t.wdata[b*8 +: 8];
            end
            `uvm_info("SCB", $sformatf(
                "WRITE committed reg[%0d] = 0x%08h (strb=%04b)", idx, shadow_regs[idx], t.wstrb),
                UVM_HIGH)
        end
    endfunction

    function void handle_read(axi4lite_transaction t);
        bit expect_okay;
        bit [31:0] exp_data;
        num_reads_checked++;
        expect_okay = addr_valid(t.addr);

        if (expect_okay && t.rresp != 2'b00) begin
            `uvm_error("SCB", $sformatf(
                "READ addr=0x%08h expected OKAY but got RRESP=%0d", t.addr, t.rresp))
            num_errors++;
        end else if (!expect_okay && t.rresp != 2'b10) begin
            `uvm_error("SCB", $sformatf(
                "READ addr=0x%08h (out of range/unaligned) expected SLVERR but got RRESP=%0d",
                t.addr, t.rresp))
            num_errors++;
        end

        if (expect_okay) begin
            exp_data = shadow_regs[t.addr >> 2];
            if (t.rdata !== exp_data) begin
                `uvm_error("SCB", $sformatf(
                    "READ addr=0x%08h data mismatch: expected 0x%08h got 0x%08h",
                    t.addr, exp_data, t.rdata))
                num_errors++;
            end else begin
                `uvm_info("SCB", $sformatf(
                    "READ addr=0x%08h data matches: 0x%08h", t.addr, t.rdata), UVM_HIGH)
            end
        end else begin
            if (t.rdata !== 32'h0) begin
                `uvm_error("SCB", $sformatf(
                    "READ addr=0x%08h out-of-range expected RDATA=0 got 0x%08h",
                    t.addr, t.rdata))
                num_errors++;
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SCB", $sformatf(
            "Scoreboard summary: writes=%0d reads=%0d errors=%0d",
            num_writes_checked, num_reads_checked, num_errors), UVM_LOW)
        if (num_errors == 0)
            `uvm_info("SCB", "SCOREBOARD: ALL CHECKS PASSED", UVM_NONE)
        else
            `uvm_error("SCB", $sformatf("SCOREBOARD: %0d CHECK(S) FAILED", num_errors))
    endfunction

endclass : axi4lite_scoreboard
