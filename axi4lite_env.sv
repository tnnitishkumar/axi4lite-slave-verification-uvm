// -----------------------------------------------------------------------------
// File        : axi4lite_env.sv
// Description : Top-level UVM environment: one active AXI4-Lite agent,
//               scoreboard, and functional coverage collector, wired
//               together through the monitor's analysis port.
// -----------------------------------------------------------------------------

class axi4lite_env extends uvm_env;

    `uvm_component_utils(axi4lite_env)

    axi4lite_agent_config cfg;
    axi4lite_agent        agent;
    axi4lite_scoreboard    scoreboard;
    axi4lite_coverage      coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(axi4lite_agent_config)::get(this, "", "cfg", cfg)) begin
            cfg = axi4lite_agent_config::type_id::create("cfg");
            if (!uvm_config_db#(virtual axi4lite_if)::get(this, "", "vif", cfg.vif))
                `uvm_fatal("ENV", "No virtual interface found for env")
            uvm_config_db#(axi4lite_agent_config)::set(this, "agent*", "cfg", cfg);
        end

        agent = axi4lite_agent::type_id::create("agent", this);

        if (cfg.enable_scoreboard)
            scoreboard = axi4lite_scoreboard::type_id::create("scoreboard", this);

        if (cfg.enable_coverage)
            coverage = axi4lite_coverage::type_id::create("coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (cfg.enable_scoreboard)
            agent.monitor.item_collected_port.connect(scoreboard.item_export);
        if (cfg.enable_coverage)
            agent.monitor.item_collected_port.connect(coverage.analysis_export);
    endfunction

endclass : axi4lite_env
