// -----------------------------------------------------------------------------
// File        : axi4lite_tb_top.sv
// Description : Top-level testbench module. Generates clock/reset, instantiates
//               the AXI4-Lite interface, the DUT, the protocol SVA checker,
//               publishes the virtual interface to the UVM config_db, and
//               kicks off run_test().
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module axi4lite_tb_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi4lite_pkg::*;
    import axi4lite_uvm_pkg::*;

    // ------------------------------------------------------------------
    // Clock / reset generation
    // ------------------------------------------------------------------
    logic ACLK;
    logic ARESETn;

    initial ACLK = 1'b0;
    always #5 ACLK = ~ACLK;  // 100 MHz

    initial begin
        ARESETn = 1'b0;
        repeat (5) @(posedge ACLK);
        ARESETn = 1'b1;
    end

    // ------------------------------------------------------------------
    // Interface + DUT + SVA checker
    // ------------------------------------------------------------------
    axi4lite_if #(.ADDR_WIDTH(AXI_ADDR_WIDTH), .DATA_WIDTH(AXI_DATA_WIDTH)) axi (
        .ACLK    (ACLK),
        .ARESETn (ARESETn)
    );

    axi4lite_slave #(
        .ADDR_WIDTH (AXI_ADDR_WIDTH),
        .DATA_WIDTH (AXI_DATA_WIDTH),
        .NREGS      (NUM_REGS)
    ) dut (
        .axi(axi.DUT)
    );

    axi4lite_protocol_sva #(
        .ADDR_WIDTH (AXI_ADDR_WIDTH),
        .DATA_WIDTH (AXI_DATA_WIDTH)
    ) sva_checker (
        .axi(axi.MONITOR_SIGNALS)
    );

    // ------------------------------------------------------------------
    // Publish the virtual interface handle and reset control, then run
    // ------------------------------------------------------------------
    initial begin
        uvm_config_db#(virtual axi4lite_if)::set(null, "*", "vif", axi);
        run_test();
    end

    // Expose ARESETn as a bit inside the interface for tests that need to
    // pulse reset mid-test (axi4lite_reset_test uses vif.ARESETn / vif.ACLK
    // directly, which are already ports on the interface).

    // ------------------------------------------------------------------
    // Waveform dump (enabled via +DUMP plusarg or VCD_DUMP define)
    // ------------------------------------------------------------------
    initial begin
        if ($test$plusargs("DUMP")) begin
            $dumpfile("axi4lite_tb.vcd");
            $dumpvars(0, axi4lite_tb_top);
        end
    end

endmodule : axi4lite_tb_top
