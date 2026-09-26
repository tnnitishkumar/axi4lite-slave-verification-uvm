// -----------------------------------------------------------------------------
// File        : axi4lite_uvm_pkg.sv
// Description : Top-level package that pulls in UVM plus every class in the
//               AXI4-Lite verification environment, in dependency order.
// -----------------------------------------------------------------------------

package axi4lite_uvm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import axi4lite_pkg::*;

    // Transaction
    `include "axi4lite_transaction.sv"

    // Agent-level config (needed by agent/driver/monitor)
    `include "axi4lite_agent_config.sv"

    // Agent building blocks
    `include "axi4lite_sequencer.sv"
    `include "axi4lite_driver.sv"
    `include "axi4lite_monitor.sv"
    `include "axi4lite_agent.sv"

    // Env building blocks
    `include "axi4lite_scoreboard.sv"
    `include "axi4lite_coverage.sv"
    `include "axi4lite_env.sv"

    // Sequences
    `include "axi4lite_seq_lib.sv"

    // Tests
    `include "axi4lite_test_lib.sv"

endpackage : axi4lite_uvm_pkg
