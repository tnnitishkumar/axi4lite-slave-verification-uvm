# AXI4-Lite Slave Verification (SystemVerilog UVM)

An AXI4-Lite slave (16 x 32-bit memory-mapped registers, WSTRB byte
enables, independent AW/W channel handling, OKAY/SLVERR responses) plus
a complete SystemVerilog UVM verification environment: transaction,
sequencer, driver, monitor, agent, reference-model scoreboard,
functional coverage, environment, 10 directed tests, a constrained-random
test, a full-regression test, protocol SVA, and simulation scripts.

## Status

- **RTL: verified.** A real (non-UVM) directed testbench
  (`sim/scripts/rtl_sanity_tb.sv`) runs against the RTL with Verilator
  and **currently passes all 21 checks, 0 errors**:
  ```
  cd sim/scripts && ./run_rtl_sanity.sh
  ...
  ALL TESTS PASSED (0 errors)
  RESULT: PASS
  ```
  Two real RTL bugs were found and fixed while building this testbench -
  see `docs/architecture.md` section 2.

- **UVM environment: complete, not executed here.** No licensed
  UVM-capable simulator (Questa/VCS/Xcelium) was available in this
  environment, and the two open-source alternatives that were installed
  and tried (Icarus Verilog 12.0, Verilator 5.020) each have a specific,
  reproducible limitation that blocks running the full UVM class
  library / covergroups (logs and exact commands in
  `docs/known_limitations.md`). Per the project's instructions, the UVM
  environment was **not weakened or simplified** to work around this -
  it is complete, standard UVM-1.2/1800.2 code, intended to be run with
  `sim/scripts/Makefile`'s Questa flow (or VCS/Xcelium, see
  `docs/simulation_instructions.md`).

## Quick start

```bash
# Verified, working, no-license-required RTL check:
cd sim/scripts && ./run_rtl_sanity.sh

# Full UVM environment (requires Questa + UVM):
cd sim/scripts
export QUESTA_UVM_HOME=$MTI_HOME/verilog_src/uvm-1.2
make compile && make smoke
```

## Documentation

- `docs/architecture.md` - RTL design and verification-environment architecture
- `docs/verification_plan.md` - features-to-verify matrix
- `docs/test_plan.md` - every test, what it checks, pass/fail criteria
- `docs/simulation_instructions.md` - how to run (Questa / VCS / RTL-only fallback)
- `docs/known_limitations.md` - the tool-blocker story, with logged evidence
- `docs/project_structure.md` - full file listing

## Layout

```
rtl/    - the DUT
sva/    - protocol assertions
tb/     - UVM environment (env/, agent/, sequences/, tests/, top/)
sim/    - scripts + logs
docs/   - documentation
```

See `docs/project_structure.md` for the full tree.
