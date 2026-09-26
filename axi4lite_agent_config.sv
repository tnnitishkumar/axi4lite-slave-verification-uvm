// -----------------------------------------------------------------------------
// File        : axi4lite_agent_config.sv
// Description : Configuration object for the AXI4-Lite agent - carries the
//               virtual interface handle and active/passive setting.
// -----------------------------------------------------------------------------

class axi4lite_agent_config extends uvm_object;

    `uvm_object_utils(axi4lite_agent_config)

    virtual axi4lite_if vif;
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    // Coverage / checking toggles
    bit enable_coverage = 1'b1;
    bit enable_scoreboard = 1'b1;

    function new(string name = "axi4lite_agent_config");
        super.new(name);
    endfunction

endclass : axi4lite_agent_config
