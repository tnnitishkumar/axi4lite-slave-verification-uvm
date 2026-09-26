// -----------------------------------------------------------------------------
// File        : axi4lite_test_lib.sv
// Description : UVM test library: base test (builds env, gets vif) plus one
//               directed test per verification-plan scenario, and a
//               constrained-random regression test.
// -----------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Base test
// ---------------------------------------------------------------------------
class axi4lite_base_test extends uvm_test;

    `uvm_component_utils(axi4lite_base_test)

    axi4lite_env    env;
    virtual axi4lite_if vif;

    function new(string name = "axi4lite_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi4lite_if)::get(this, "", "vif", vif))
            `uvm_fatal("TEST", "No virtual interface found for test - check tb_top config_db set")
        uvm_config_db#(virtual axi4lite_if)::set(this, "env", "vif", vif);
        env = axi4lite_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

    // Common watchdog so a stuck test doesn't hang the regression forever.
    task run_phase(uvm_phase phase);
        uvm_objection objection = phase.get_objection();
        fork
            begin
                #(50_000 * 1ns);
                `uvm_fatal("TEST", "Global watchdog timeout - test did not finish")
            end
        join_none
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_server svr = uvm_report_server::get_server();
        super.report_phase(phase);
        if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) > 0)
            `uvm_info("TEST", "TEST RESULT: FAIL", UVM_NONE)
        else
            `uvm_info("TEST", "TEST RESULT: PASS", UVM_NONE)
    endfunction

endclass : axi4lite_base_test


// ---------------------------------------------------------------------------
// Smoke test: minimal single write + read, fast sanity check
// ---------------------------------------------------------------------------
class axi4lite_smoke_test extends axi4lite_base_test;
    `uvm_component_utils(axi4lite_smoke_test)
    function new(string name = "axi4lite_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        axi4lite_single_rw_seq seq = axi4lite_single_rw_seq::type_id::create("seq");
        super.run_phase(phase);
        phase.raise_objection(this);
        seq.start(env.agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass : axi4lite_smoke_test


// ---------------------------------------------------------------------------
// Directed tests, one per verification-plan scenario
// ---------------------------------------------------------------------------
`define AXI4LITE_DIRECTED_TEST(TEST_NAME, SEQ_TYPE) \
class TEST_NAME extends axi4lite_base_test; \
    `uvm_component_utils(TEST_NAME) \
    function new(string name = `"TEST_NAME`", uvm_component parent = null); \
        super.new(name, parent); \
    endfunction \
    task run_phase(uvm_phase phase); \
        SEQ_TYPE seq = SEQ_TYPE::type_id::create("seq"); \
        super.run_phase(phase); \
        phase.raise_objection(this); \
        seq.start(env.agent.sequencer); \
        phase.drop_objection(this); \
    endtask \
endclass : TEST_NAME

`AXI4LITE_DIRECTED_TEST(axi4lite_single_rw_test,            axi4lite_single_rw_seq)
`AXI4LITE_DIRECTED_TEST(axi4lite_multiple_rw_test,          axi4lite_multiple_rw_seq)
`AXI4LITE_DIRECTED_TEST(axi4lite_back_to_back_test,         axi4lite_back_to_back_seq)
`AXI4LITE_DIRECTED_TEST(axi4lite_independent_aw_w_test,     axi4lite_independent_aw_w_seq)
`AXI4LITE_DIRECTED_TEST(axi4lite_wstrb_partial_test,        axi4lite_wstrb_partial_seq)
`AXI4LITE_DIRECTED_TEST(axi4lite_invalid_addr_test,         axi4lite_invalid_addr_seq)
`AXI4LITE_DIRECTED_TEST(axi4lite_bready_backpressure_test,  axi4lite_bready_backpressure_seq)
`AXI4LITE_DIRECTED_TEST(axi4lite_rready_backpressure_test,  axi4lite_rready_backpressure_seq)
`AXI4LITE_DIRECTED_TEST(axi4lite_slave_stall_test,          axi4lite_slave_stall_seq)
`AXI4LITE_DIRECTED_TEST(axi4lite_corner_case_test,          axi4lite_corner_case_seq)


// ---------------------------------------------------------------------------
// Reset test: explicitly pulses ARESETn mid-test (via the virtual
// interface, driven from the test since reset is a DUT-level, not
// sequence-level, concern) and checks the bus is still functional after.
// ---------------------------------------------------------------------------
class axi4lite_reset_test extends axi4lite_base_test;
    `uvm_component_utils(axi4lite_reset_test)
    function new(string name = "axi4lite_reset_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        axi4lite_single_rw_seq seq1 = axi4lite_single_rw_seq::type_id::create("seq1");
        axi4lite_single_rw_seq seq2 = axi4lite_single_rw_seq::type_id::create("seq2");
        super.run_phase(phase);
        phase.raise_objection(this);

        seq1.start(env.agent.sequencer);

        `uvm_info("TEST", "Asserting mid-test reset pulse", UVM_LOW)
        vif.ARESETn <= 1'b0;
        repeat (5) @(posedge vif.ACLK);
        vif.ARESETn <= 1'b1;
        repeat (2) @(posedge vif.ACLK);

        seq2.start(env.agent.sequencer);

        phase.drop_objection(this);
    endtask
endclass : axi4lite_reset_test


// ---------------------------------------------------------------------------
// Constrained-random regression test
// ---------------------------------------------------------------------------
class axi4lite_random_test extends axi4lite_base_test;
    `uvm_component_utils(axi4lite_random_test)
    function new(string name = "axi4lite_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        axi4lite_random_seq seq = axi4lite_random_seq::type_id::create("seq");
        super.run_phase(phase);
        phase.raise_objection(this);
        if (!seq.randomize())
            `uvm_error("TEST", "randomize failed for axi4lite_random_seq")
        seq.start(env.agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass : axi4lite_random_test


// ---------------------------------------------------------------------------
// Full regression test: runs every directed scenario back-to-back plus a
// random tail, in one test (useful for a single "run everything" target).
// ---------------------------------------------------------------------------
class axi4lite_full_regression_test extends axi4lite_base_test;
    `uvm_component_utils(axi4lite_full_regression_test)
    function new(string name = "axi4lite_full_regression_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        axi4lite_single_rw_seq              s1  = axi4lite_single_rw_seq::type_id::create("s1");
        axi4lite_multiple_rw_seq            s2  = axi4lite_multiple_rw_seq::type_id::create("s2");
        axi4lite_back_to_back_seq           s3  = axi4lite_back_to_back_seq::type_id::create("s3");
        axi4lite_independent_aw_w_seq       s4  = axi4lite_independent_aw_w_seq::type_id::create("s4");
        axi4lite_wstrb_partial_seq          s5  = axi4lite_wstrb_partial_seq::type_id::create("s5");
        axi4lite_invalid_addr_seq           s6  = axi4lite_invalid_addr_seq::type_id::create("s6");
        axi4lite_bready_backpressure_seq    s7  = axi4lite_bready_backpressure_seq::type_id::create("s7");
        axi4lite_rready_backpressure_seq    s8  = axi4lite_rready_backpressure_seq::type_id::create("s8");
        axi4lite_slave_stall_seq            s9  = axi4lite_slave_stall_seq::type_id::create("s9");
        axi4lite_corner_case_seq            s10 = axi4lite_corner_case_seq::type_id::create("s10");
        axi4lite_random_seq                 s11 = axi4lite_random_seq::type_id::create("s11");

        super.run_phase(phase);
        phase.raise_objection(this);

        s1.start(env.agent.sequencer);
        s2.start(env.agent.sequencer);
        s3.start(env.agent.sequencer);
        s4.start(env.agent.sequencer);
        s5.start(env.agent.sequencer);
        s6.start(env.agent.sequencer);
        s7.start(env.agent.sequencer);
        s8.start(env.agent.sequencer);
        s9.start(env.agent.sequencer);
        s10.start(env.agent.sequencer);
        if (!s11.randomize() with { num_txns inside {[30:60]}; })
            `uvm_error("TEST", "randomize failed for s11")
        s11.start(env.agent.sequencer);

        phase.drop_objection(this);
    endtask
endclass : axi4lite_full_regression_test
