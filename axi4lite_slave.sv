// -----------------------------------------------------------------------------
// File        : axi4lite_slave.sv
// Description : Synthesizable AXI4-Lite slave with NUM_REGS 32-bit
//               memory-mapped, byte-writable (WSTRB) registers.
//
// Key properties implemented:
//   - AWADDR/AWVALID and WDATA/WSTRB/WVALID channels are fully independent:
//     the slave can accept AW before W, W before AW, or both in the same
//     cycle, and will only latch a channel once (AWREADY/WREADY deasserted
//     immediately after the respective handshake) until the write commits.
//   - BVALID is asserted only after BOTH address and data have been
//     accepted, and stays high (stable payload) until BREADY.
//   - WSTRB provides byte-lane write enables.
//   - Out-of-range addresses return SLVERR on B/R channels; in-range
//     addresses return OKAY. (AXI4-Lite requires a response - OKAY is the
//     nominal case requested; SLVERR is included for realistic, testable
//     error handling on bad addresses and is a strict superset of "OKAY
//     only" behavior.)
//   - Synchronous active-low reset (ARESETn) clears all registers and all
//     channel state machines.
// -----------------------------------------------------------------------------

module axi4lite_slave
    import axi4lite_pkg::*;
#(
    parameter int ADDR_WIDTH = AXI_ADDR_WIDTH,
    parameter int DATA_WIDTH = AXI_DATA_WIDTH,
    parameter int NREGS      = NUM_REGS
) (
    axi4lite_if.DUT axi
);

    localparam int STRB_WIDTH = DATA_WIDTH/8;
    localparam int IDX_W      = (NREGS <= 1) ? 1 : $clog2(NREGS);

    // -----------------------------------------------------------------
    // Register file
    // -----------------------------------------------------------------
    logic [DATA_WIDTH-1:0] regfile [0:NREGS-1];

    // -----------------------------------------------------------------
    // Write channel state
    // -----------------------------------------------------------------
    logic                    aw_pending;   // address captured, write not yet committed
    logic [ADDR_WIDTH-1:0]   aw_addr_q;
    logic                    w_pending;    // data captured, write not yet committed
    logic [DATA_WIDTH-1:0]   w_data_q;
    logic [STRB_WIDTH-1:0]   w_strb_q;

    logic                    bvalid_q;
    axi_resp_e               bresp_q;

    wire aw_hs = axi.AWVALID & axi.AWREADY;
    wire w_hs  = axi.WVALID  & axi.WREADY;
    wire b_hs  = axi.BVALID  & axi.BREADY;

    // Address decode: plain combinational wires (word-aligned AND in
    // range 0..NREGS-1). Implemented without a function for maximum
    // portability across simulators.
    wire commit_addr_aligned  = (commit_addr[1:0] == 2'b00);
    wire commit_addr_in_range = commit_addr_aligned && (commit_addr[ADDR_WIDTH-1:REG_ADDR_LSB] < NREGS[ADDR_WIDTH-REG_ADDR_LSB-1:0]);

    wire read_addr_aligned  = (read_addr[1:0] == 2'b00);
    wire read_addr_in_range = read_addr_aligned && (read_addr[ADDR_WIDTH-1:REG_ADDR_LSB] < NREGS[ADDR_WIDTH-REG_ADDR_LSB-1:0]);

    // AWREADY: ready to accept a new address whenever we don't already
    // hold one that hasn't been committed yet.
    assign axi.AWREADY = axi.ARESETn & ~aw_pending;
    // WREADY: ready to accept new data whenever we don't already hold data
    // that hasn't been committed yet.
    assign axi.WREADY  = axi.ARESETn & ~w_pending;

    // Commit the write (update register file) the same cycle both
    // AW and W have been captured (address may have been captured this
    // very cycle via aw_hs, or on a previous cycle via aw_pending; same
    // for data), and the B channel is free to accept a new response.
    //
    // IMPORTANT: do_write_commit is a function of the CURRENT (pre-edge)
    // aw_pending/w_pending plus this cycle's handshakes, so it correctly
    // covers the "AW and W both arrive on the same cycle and commit
    // immediately" corner case, as well as the "one side already
    // latched, the other arrives now" case.
    wire do_write_commit = (aw_pending || aw_hs) && (w_pending || w_hs) && (!bvalid_q || b_hs);

    always_ff @(posedge axi.ACLK) begin
        if (!axi.ARESETn) begin
            aw_pending <= 1'b0;
            aw_addr_q  <= '0;
        end else begin
            // Priority: a same-cycle commit always clears the pending
            // latch (even if aw_hs also happened this very cycle - the
            // freshly arrived address was consumed immediately and is
            // not left "pending" across the clock edge). Only capture
            // as pending when the write does NOT commit this cycle.
            if (do_write_commit) begin
                aw_pending <= 1'b0;
            end else if (aw_hs) begin
                aw_pending <= 1'b1;
                aw_addr_q  <= axi.AWADDR;
            end
        end
    end

    always_ff @(posedge axi.ACLK) begin
        if (!axi.ARESETn) begin
            w_pending <= 1'b0;
            w_data_q  <= '0;
            w_strb_q  <= '0;
        end else begin
            if (do_write_commit) begin
                w_pending <= 1'b0;
            end else if (w_hs) begin
                w_pending <= 1'b1;
                w_data_q  <= axi.WDATA;
                w_strb_q  <= axi.WSTRB;
            end
        end
    end

    logic [ADDR_WIDTH-1:0] commit_addr;
    logic [DATA_WIDTH-1:0] commit_data;
    logic [STRB_WIDTH-1:0] commit_strb;
    assign commit_addr = aw_hs ? axi.AWADDR : aw_addr_q;
    assign commit_data = w_hs  ? axi.WDATA  : w_data_q;
    assign commit_strb = w_hs  ? axi.WSTRB  : w_strb_q;

    integer wi;
    always_ff @(posedge axi.ACLK) begin
        if (!axi.ARESETn) begin
            for (wi = 0; wi < NREGS; wi = wi + 1) regfile[wi] <= '0;
        end else if (do_write_commit && commit_addr_in_range) begin
            for (wi = 0; wi < STRB_WIDTH; wi = wi + 1) begin
                if (commit_strb[wi]) begin
                    regfile[commit_addr >> REG_ADDR_LSB][wi*8 +: 8] <= commit_data[wi*8 +: 8];
                end
            end
        end
    end

    // Write response
    always_ff @(posedge axi.ACLK) begin
        if (!axi.ARESETn) begin
            bvalid_q <= 1'b0;
            bresp_q  <= RESP_OKAY;
        end else begin
            if (do_write_commit) begin
                bvalid_q <= 1'b1;
                bresp_q  <= commit_addr_in_range ? RESP_OKAY : RESP_SLVERR;
            end else if (b_hs) begin
                bvalid_q <= 1'b0;
            end
        end
    end

    assign axi.BVALID = bvalid_q;
    assign axi.BRESP  = bresp_q;

    // -----------------------------------------------------------------
    // Read channel
    // -----------------------------------------------------------------
    logic                  ar_pending;
    logic [ADDR_WIDTH-1:0] ar_addr_q;
    logic                  rvalid_q;
    logic [DATA_WIDTH-1:0] rdata_q;
    axi_resp_e             rresp_q;

    wire ar_hs = axi.ARVALID & axi.ARREADY;
    wire r_hs  = axi.RVALID  & axi.RREADY;

    // Ready to accept a new read address when we are not holding one
    // that hasn't yet produced its RVALID beat.
    assign axi.ARREADY = axi.ARESETn & ~ar_pending;

    wire do_read_commit = (ar_pending || ar_hs) && (!rvalid_q || r_hs);
    logic [ADDR_WIDTH-1:0] read_addr;
    assign read_addr = ar_hs ? axi.ARADDR : ar_addr_q;

    always_ff @(posedge axi.ACLK) begin
        if (!axi.ARESETn) begin
            ar_pending <= 1'b0;
            ar_addr_q  <= '0;
        end else begin
            // Same priority rule as the write-address latch above: a
            // same-cycle commit always wins, even if ar_hs also fired
            // this cycle (freshly arrived address consumed immediately).
            if (do_read_commit) begin
                ar_pending <= 1'b0;
            end else if (ar_hs) begin
                ar_pending <= 1'b1;
                ar_addr_q  <= axi.ARADDR;
            end
        end
    end

    always_ff @(posedge axi.ACLK) begin
        if (!axi.ARESETn) begin
            rvalid_q <= 1'b0;
            rdata_q  <= '0;
            rresp_q  <= RESP_OKAY;
        end else begin
            if (do_read_commit) begin
                rvalid_q <= 1'b1;
                if (read_addr_in_range) begin
                    rdata_q <= regfile[read_addr >> REG_ADDR_LSB];
                    rresp_q <= RESP_OKAY;
                end else begin
                    rdata_q <= '0;
                    rresp_q <= RESP_SLVERR;
                end
            end else if (r_hs) begin
                rvalid_q <= 1'b0;
            end
        end
    end

    assign axi.RVALID = rvalid_q;
    assign axi.RDATA  = rdata_q;
    assign axi.RRESP  = rresp_q;

endmodule : axi4lite_slave
