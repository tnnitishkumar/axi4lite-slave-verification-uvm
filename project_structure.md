# Project Structure

```
AXI4-Lite-Slave-Verification-UVM/
|- rtl/
|  |- axi4lite_pkg.sv          # parameters, address-map constants, resp enum
|  |- axi4lite_if.sv            # AXI4-Lite interface + clocking blocks + modports
|  \- axi4lite_slave.sv          # the DUT
|
|- sva/
|  \- axi4lite_protocol_sva.sv    # protocol checker, bound alongside the DUT
|
|- tb/
|  |- axi4lite_uvm_pkg.sv          # top-level package, includes everything below
|  |- env/
|  |  |- axi4lite_transaction.sv    # uvm_sequence_item
|  |  |- axi4lite_scoreboard.sv      # reference-model checker
|  |  |- axi4lite_coverage.sv         # functional coverage (uvm_subscriber)
|  |  \- axi4lite_env.sv               # top-level env
|  |- agent/
|  |  |- axi4lite_agent_config.sv       # vif handle + active/passive + toggles
|  |  |- axi4lite_sequencer.sv           # uvm_sequencer#(axi4lite_transaction)
|  |  |- axi4lite_driver.sv               # pin-level driver
|  |  |- axi4lite_monitor.sv               # passive bus monitor
|  |  \- axi4lite_agent.sv                  # bundles the three above
|  |- sequences/
|  |  \- axi4lite_seq_lib.sv                 # base seq + 10 directed seqs + random seq
|  |- tests/
|  |  \- axi4lite_test_lib.sv                 # base test + 10 directed tests + random + full-regression
|  \- top/
|     \- axi4lite_tb_top.sv                    # clock/reset gen, DUT+IF+SVA instantiation, run_test()
|
|- sim/
|  |- scripts/
|  |  |- Makefile                    # Questa-primary flow + Verilator RTL-only fallback
|  |  |- run_rtl_sanity.sh            # verified, working Verilator fallback (see docs/known_limitations.md)
|  |  \- rtl_sanity_tb.sv              # the non-UVM directed testbench that fallback runs
|  \- logs/                              # tool-output evidence referenced by docs/known_limitations.md
|
\- docs/
   |- README.md                   -> (see project root README.md)
   |- architecture.md              # RTL + env architecture, including 2 bugs found & fixed
   |- verification_plan.md          # features-to-verify matrix
   |- test_plan.md                   # test-by-test description + pass/fail criteria
   |- simulation_instructions.md      # how to run, 3 options
   |- known_limitations.md             # honest, evidence-backed tool-blocker writeup
   \- project_structure.md               # this file
```

## File count summary

- RTL: 3 files
- SVA: 1 file
- UVM testbench: 12 files (1 package + transaction + config + sequencer +
  driver + monitor + agent + scoreboard + coverage + env + seq lib + test
  lib) + 1 top module
- Simulation: 1 Makefile + 1 shell script + 1 non-UVM sanity testbench
- Docs: 6 files (including this one)
