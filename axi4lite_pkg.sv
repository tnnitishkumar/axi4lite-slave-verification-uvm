// -----------------------------------------------------------------------------
// File        : axi4lite_pkg.sv
// Description : Shared parameters / typedefs for the AXI4-Lite slave RTL.
// -----------------------------------------------------------------------------
`ifndef AXI4LITE_PKG_SV
`define AXI4LITE_PKG_SV

package axi4lite_pkg;

    parameter int AXI_ADDR_WIDTH   = 32;
    parameter int AXI_DATA_WIDTH   = 32;
    parameter int AXI_STRB_WIDTH   = AXI_DATA_WIDTH/8;

    // Number of 32-bit memory-mapped registers implemented by the slave.
    parameter int NUM_REGS         = 16;                       // 8-16 registers
    parameter int REG_ADDR_LSB     = 2;                        // word aligned
    parameter int REG_INDEX_WIDTH  = $clog2(NUM_REGS);

    // AXI4-Lite response encoding (subset actually driven: OKAY / SLVERR)
    typedef enum logic [1:0] {
        RESP_OKAY   = 2'b00,
        RESP_EXOKAY = 2'b01,   // unused for AXI4-Lite, kept for completeness
        RESP_SLVERR = 2'b10,
        RESP_DECERR = 2'b11
    } axi_resp_e;

endpackage : axi4lite_pkg

`endif
