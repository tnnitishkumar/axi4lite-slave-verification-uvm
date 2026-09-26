// -----------------------------------------------------------------------------
// File        : axi4lite_agent.sv
// Description : Standard UVM agent bundling sequencer + driver + monitor.
//               Supports UVM_ACTIVE / UVM_PASSIVE via the agent config.
// -----------------------------------------------------------------------------

class axi4lite_agent extends uvm_agent;

    `uvm_component_utils(axi4lite_agent)

    axi4lite_agent_config cfg;
    axi4lite_sequencer    sequencer;
    axi4lite_driver       driver;
    axi4lite_monitor      monitor;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(axi4lite_agent_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("AGENT", "No agent config found")

        monitor = axi4lite_monitor::type_id::create("monitor", this);

        if (cfg.is_active == UVM_ACTIVE) begin
            sequencer = axi4lite_sequencer::type_id::create("sequencer", this);
            driver    = axi4lite_driver::type_id::create("driver", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (cfg.is_active == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass : axi4lite_agent
