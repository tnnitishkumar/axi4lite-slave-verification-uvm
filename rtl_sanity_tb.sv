// -----------------------------------------------------------------------------
// File        : rtl_sanity_tb.sv
// Description : Lightweight, non-UVM, procedural sanity testbench used ONLY
//               to functionally validate the RTL DUT quickly with Icarus
//               Verilog (which has limited SystemVerilog class/UVM support).
//               This is NOT part of the UVM verification environment; the
//               real, complete verification environment is under tb/.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module rtl_sanity_tb;
    timeunit 1ns; timeprecision 1ps;

    import axi4lite_pkg::*;

    logic clk = 0;
    logic rstn = 0;

    always #5 clk = ~clk;

    axi4lite_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) axi (.ACLK(clk), .ARESETn(rstn));

    axi4lite_slave dut (.axi(axi.DUT));

    axi4lite_protocol_sva sva_chk (.axi(axi.MONITOR_SIGNALS));

    int errors = 0;

    // Default drive values
    task automatic init_signals;
        axi.AWADDR   = '0; axi.AWPROT = '0; axi.AWVALID = 0;
        axi.WDATA    = '0; axi.WSTRB  = '0; axi.WVALID  = 0;
        axi.BREADY   = 0;
        axi.ARADDR   = '0; axi.ARPROT = '0; axi.ARVALID = 0;
        axi.RREADY   = 0;
    endtask

    task automatic do_reset;
        rstn = 0;
        init_signals();
        repeat (4) @(posedge clk);
        rstn = 1;
        @(posedge clk);
    endtask

    // Independent AW/W arrival: drive both channels from a single,
    // sequential per-cycle loop (no fork/join) so the two channels can
    // start on different cycles (aw_delay vs w_delay) while remaining
    // simulator-portable. This mirrors how the UVM driver's two virtual
    // processes are modeled logically, without relying on fork/join
    // + blocking-vs-nonblocking edge cases in lighter-weight simulators.
    task automatic axi_write(
        input  [31:0] addr,
        input  [31:0] data,
        input  [3:0]  strb,
        input  int    aw_delay,
        input  int    w_delay,
        output [1:0]  resp
    );
        int cyc;
        bit aw_issued, aw_done, w_issued, w_done;
        bit aw_ready_sample, w_ready_sample;
        cyc = 0; aw_issued = 0; aw_done = 0; w_issued = 0; w_done = 0;
        axi.AWVALID = 0;
        axi.WVALID  = 0;
        while (!(aw_done && w_done)) begin
            if (!aw_issued && cyc >= aw_delay) begin
                axi.AWADDR  = addr;
                axi.AWVALID = 1;
                aw_issued = 1;
            end
            if (!w_issued && cyc >= w_delay) begin
                axi.WDATA  = data;
                axi.WSTRB  = strb;
                axi.WVALID = 1;
                w_issued = 1;
            end
            // Sample READY as it stands *before* the clock edge - this is
            // the value that actually determines whether a handshake
            // occurs at this edge (AXI handshakes are defined by VALID &
            // READY both high going into the edge).
            aw_ready_sample = axi.AWREADY;
            w_ready_sample  = axi.WREADY;
            @(posedge clk);
            if (aw_issued && !aw_done && aw_ready_sample) begin
                axi.AWVALID = 0;
                aw_done = 1;
            end
            if (w_issued && !w_done && w_ready_sample) begin
                axi.WVALID = 0;
                w_done = 1;
            end
            cyc++;
            if (cyc > 50) begin
                $display("[ERROR] axi_write did not complete within 50 cycles - possible DUT deadlock");
                break;
            end
        end
        axi.BREADY = 1;
        while (!axi.BVALID) @(posedge clk);
        resp = axi.BRESP;
        @(posedge clk);
        axi.BREADY = 0;
    endtask

    task automatic axi_read(input [31:0] addr, output [31:0] data, output [1:0] resp);
        bit ar_ready_sample;
        axi.ARADDR  = addr;
        axi.ARVALID = 1;
        forever begin
            ar_ready_sample = axi.ARREADY;
            @(posedge clk);
            if (ar_ready_sample) break;
        end
        axi.ARVALID = 0;
        axi.RREADY  = 1;
        while (!axi.RVALID) @(posedge clk);
        data = axi.RDATA;
        resp = axi.RRESP;
        @(posedge clk);
        axi.RREADY = 0;
    endtask

    task automatic check(input bit cond, input string msg);
        if (!cond) begin
            errors++;
            $display("[FAIL] %s", msg);
        end else begin
            $display("[PASS] %s", msg);
        end
    endtask

    logic [31:0] rdata;
    logic [1:0]  resp;

    initial begin
        do_reset();

        // Test 1: single write / read back, word aligned addr 0
        axi_write(32'h0000_0000, 32'hDEAD_BEEF, 4'hF, 0, 0, resp);
        check(resp == RESP_OKAY, "T1: write resp OKAY");
        axi_read(32'h0000_0000, rdata, resp);
        check(rdata == 32'hDEAD_BEEF, "T1: readback data matches");
        check(resp == RESP_OKAY, "T1: read resp OKAY");

        // Test 2: independent AW/W arrival - AW first, W much later
        axi_write(32'h0000_0004, 32'h1234_5678, 4'hF, 0, 5, resp);
        check(resp == RESP_OKAY, "T2: AW-before-W write resp OKAY");
        axi_read(32'h0000_0004, rdata, resp);
        check(rdata == 32'h1234_5678, "T2: AW-before-W readback matches");

        // Test 3: independent AW/W arrival - W first, AW much later
        axi_write(32'h0000_0008, 32'hCAFEBABE, 4'hF, 6, 0, resp);
        check(resp == RESP_OKAY, "T3: W-before-AW write resp OKAY");
        axi_read(32'h0000_0008, rdata, resp);
        check(rdata == 32'hCAFEBABE, "T3: W-before-AW readback matches");

        // Test 4: WSTRB partial write - only byte 0 and byte 2
        axi_write(32'h0000_0000, 32'h0000_0000, 4'hF, 0, 0, resp); // clear
        axi_write(32'h0000_0000, 32'hAABBCCDD, 4'b0101, 0, 0, resp);
        axi_read(32'h0000_0000, rdata, resp);
        check(rdata == 32'h00BB00DD, $sformatf("T4: WSTRB partial write got 0x%08h exp 0x00BB00DD", rdata));

        // Test 5: invalid address (out of range) -> SLVERR
        axi_write(32'hFFFF_FFF0, 32'hFFFF_FFFF, 4'hF, 0, 0, resp);
        check(resp == RESP_SLVERR, "T5: write to invalid addr -> SLVERR");
        axi_read(32'hFFFF_FFF0, rdata, resp);
        check(resp == RESP_SLVERR, "T5: read from invalid addr -> SLVERR");

        // Test 6: unaligned address -> SLVERR
        axi_write(32'h0000_0001, 32'hFFFF_FFFF, 4'hF, 0, 0, resp);
        check(resp == RESP_SLVERR, "T6: unaligned write addr -> SLVERR");

        // Test 7: back-to-back writes to different regs
        begin
            logic [1:0] r0, r1;
            axi_write(32'h0000_000C, 32'h1111_1111, 4'hF, 0, 0, r0);
            axi_write(32'h0000_0010, 32'h2222_2222, 4'hF, 0, 0, r1);
            check(r0 == RESP_OKAY && r1 == RESP_OKAY, "T7: back-to-back writes both OKAY");
        end
        axi_read(32'h0000_000C, rdata, resp);
        check(rdata == 32'h1111_1111, "T7: reg 3 readback");
        axi_read(32'h0000_0010, rdata, resp);
        check(rdata == 32'h2222_2222, "T7: reg 4 readback");

        // Test 8: BREADY backpressure (hold BREADY low for a while)
        begin
            bit aw_rdy_s, w_rdy_s;
            bit aw_hs_seen, w_hs_seen;
            axi.AWADDR  = 32'h0000_0014; axi.AWVALID = 1;
            axi.WDATA   = 32'h3333_3333; axi.WSTRB = 4'hF; axi.WVALID = 1;
            aw_hs_seen = 0; w_hs_seen = 0;
            while (!(aw_hs_seen && w_hs_seen)) begin
                aw_rdy_s = axi.AWREADY;
                w_rdy_s  = axi.WREADY;
                @(posedge clk);
                if (aw_rdy_s) begin axi.AWVALID = 0; aw_hs_seen = 1; end
                if (w_rdy_s)  begin axi.WVALID  = 0; w_hs_seen  = 1; end
            end
            // Do NOT assert BREADY for a few cycles; BVALID must hold stable
            repeat (3) begin
                @(posedge clk); #0;
                check(axi.BVALID === 1'b1, "T8: BVALID held stable while BREADY low");
            end
            axi.BREADY = 1;
            while (!axi.BVALID) @(posedge clk);
            @(posedge clk);
            axi.BREADY = 0;
        end

        // Test 9: RREADY backpressure
        begin
            bit ar_rdy_s;
            axi.ARADDR = 32'h0000_0014; axi.ARVALID = 1;
            forever begin
                ar_rdy_s = axi.ARREADY;
                @(posedge clk);
                if (ar_rdy_s) break;
            end
            axi.ARVALID = 0;
            repeat (3) begin
                @(posedge clk); #0;
                check(axi.RVALID === 1'b1, "T9: RVALID held stable while RREADY low");
            end
            axi.RREADY = 1;
            while (!axi.RVALID) @(posedge clk);
            check(axi.RDATA == 32'h3333_3333, "T9: RREADY-backpressured read data correct");
            @(posedge clk);
            axi.RREADY = 0;
        end

        // Test 10: reset mid-operation clears state
        do_reset();
        axi_read(32'h0000_0000, rdata, resp);
        check(rdata == 32'h0, "T10: register cleared after reset");

        $display("--------------------------------------------------");
        if (errors == 0) $display("ALL TESTS PASSED (0 errors)");
        else $display("TESTS FAILED: %0d error(s)", errors);
        $display("--------------------------------------------------");

        $finish;
    end

    initial begin
        #100000;
        $display("[TIMEOUT] rtl_sanity_tb did not finish in time");
        $finish;
    end

endmodule
