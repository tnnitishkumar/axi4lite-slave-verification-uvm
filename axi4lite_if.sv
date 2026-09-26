// -----------------------------------------------------------------------------
// File        : axi4lite_if.sv
// Description : AXI4-Lite interface bundle (32-bit address, 32-bit data).
//               Shared by RTL DUT and UVM testbench (driver/monitor use
//               clocking blocks / modports to keep race-free sampling).
// -----------------------------------------------------------------------------

interface axi4lite_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (
    input logic ACLK,
    input logic ARESETn
);

    // Write address channel
    logic [ADDR_WIDTH-1:0]   AWADDR;
    logic [2:0]               AWPROT;
    logic                      AWVALID;
    logic                      AWREADY;

    // Write data channel
    logic [DATA_WIDTH-1:0]           WDATA;
    logic [(DATA_WIDTH/8)-1:0]       WSTRB;
    logic                             WVALID;
    logic                             WREADY;

    // Write response channel
    logic [1:0]  BRESP;
    logic         BVALID;
    logic         BREADY;

    // Read address channel
    logic [ADDR_WIDTH-1:0]  ARADDR;
    logic [2:0]              ARPROT;
    logic                     ARVALID;
    logic                     ARREADY;

    // Read data channel
    logic [DATA_WIDTH-1:0]  RDATA;
    logic [1:0]               RRESP;
    logic                      RVALID;
    logic                      RREADY;

    // ---------------------------------------------------------------
    // Modports
    // ---------------------------------------------------------------
    modport DUT (
        input  ACLK, ARESETn,
        input  AWADDR, AWPROT, AWVALID,
        output AWREADY,
        input  WDATA, WSTRB, WVALID,
        output WREADY,
        output BRESP, BVALID,
        input  BREADY,
        input  ARADDR, ARPROT, ARVALID,
        output ARREADY,
        output RDATA, RRESP, RVALID,
        input  RREADY
    );

    modport TB (
        input  ACLK, ARESETn,
        output AWADDR, AWPROT, AWVALID,
        input  AWREADY,
        output WDATA, WSTRB, WVALID,
        input  WREADY,
        input  BRESP, BVALID,
        output BREADY,
        output ARADDR, ARPROT, ARVALID,
        input  ARREADY,
        input  RDATA, RRESP, RVALID,
        output RREADY
    );

    // Read-only view for passive observers (monitor / SVA checker module).
    // Plain signal modport (no clocking wrapper) for maximum tool portability.
    modport MONITOR_SIGNALS (
        input ACLK, ARESETn,
        input AWADDR, AWPROT, AWVALID, AWREADY,
        input WDATA, WSTRB, WVALID, WREADY,
        input BRESP, BVALID, BREADY,
        input ARADDR, ARPROT, ARVALID, ARREADY,
        input RDATA, RRESP, RVALID, RREADY
    );

    // ---------------------------------------------------------------
    // Clocking block for driver (drives on posedge, avoids races)
    // ---------------------------------------------------------------
    clocking drv_cb @(posedge ACLK);
        output AWADDR, AWPROT, AWVALID;
        input  AWREADY;
        output WDATA, WSTRB, WVALID;
        input  WREADY;
        input  BRESP, BVALID;
        output BREADY;
        output ARADDR, ARPROT, ARVALID;
        input  ARREADY;
        input  RDATA, RRESP, RVALID;
        output RREADY;
    endclocking

    clocking mon_cb @(posedge ACLK);
        input AWADDR, AWPROT, AWVALID, AWREADY;
        input WDATA, WSTRB, WVALID, WREADY;
        input BRESP, BVALID, BREADY;
        input ARADDR, ARPROT, ARVALID, ARREADY;
        input RDATA, RRESP, RVALID, RREADY;
    endclocking

    // NOTE: "modport <name> (clocking cb, ...)" is deliberately not used
    // here - it is poorly supported by open-source tools (Verilator/
    // Icarus). The UVM driver/monitor instead reference the clocking
    // blocks directly through the virtual interface handle, e.g.
    // `vif.drv_cb.AWVALID <= 1'b1;` / `@(vif.mon_cb);` which is fully
    // portable and is the more common idiom in real UVM environments.

endinterface : axi4lite_if
