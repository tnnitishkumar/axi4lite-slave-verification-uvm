# Simulation Instructions

## Option A — Questa (intended flow, full UVM environment)

Requires a Questa install with a bundled UVM-1.2 (or 1800.2) library.

```bash
cd sim/scripts
export QUESTA_UVM_HOME=$MTI_HOME/verilog_src/uvm-1.2   # adjust to your install
make compile              # compile RTL + SVA + UVM testbench
make smoke                 # run axi4lite_smoke_test
make test TEST=axi4lite_independent_aw_w_test   # run any single test
make directed                # run every directed test once
make regression                # run full_regression across 5 random seeds
```

Logs land in `sim/logs/`. Waveforms: add `-do "log -r /*; run -all"` to
the `vsim` invocation in the Makefile, or run `+DUMP` and inspect with
your simulator's waveform viewer.

Available `TEST` values (see `docs/test_plan.md` for what each covers):
`axi4lite_smoke_test`, `axi4lite_reset_test`, `axi4lite_single_rw_test`,
`axi4lite_multiple_rw_test`, `axi4lite_back_to_back_test`,
`axi4lite_independent_aw_w_test`, `axi4lite_wstrb_partial_test`,
`axi4lite_invalid_addr_test`, `axi4lite_bready_backpressure_test`,
`axi4lite_rready_backpressure_test`, `axi4lite_slave_stall_test`,
`axi4lite_corner_case_test`, `axi4lite_random_test`,
`axi4lite_full_regression_test`.

## Option B — VCS / Xcelium

The environment uses only standard UVM-1.2/1800.2 constructs, no
simulator-specific extensions. Compile all files under `rtl/`, `sva/`,
and `tb/` (in the order `axi4lite_pkg.sv` -> `axi4lite_if.sv` ->
`axi4lite_slave.sv` -> `axi4lite_protocol_sva.sv` -> `axi4lite_uvm_pkg.sv`
-> `tb/top/axi4lite_tb_top.sv`) against your simulator's UVM library,
then run with `+UVM_TESTNAME=<test>`.

## Option C — No EDA license available (RTL-only fallback, verified working)

`sim/scripts/run_rtl_sanity.sh` runs the actual, working, verified flow
used during development of this project: Verilator lint of RTL+SVA,
followed by a real (non-UVM) directed simulation covering the same
scenarios as the UVM directed tests. This requires only Verilator
(`apt-get install verilator`, tested with 5.020) - no UVM library, no
license.

```bash
cd sim/scripts
./run_rtl_sanity.sh
```

Expected output ends with:
```
ALL TESTS PASSED (0 errors)
RESULT: PASS
```

See `docs/known_limitations.md` for exactly why this fallback exists
and what it does and does not cover relative to the full UVM
environment.

## Waveform dumping

`tb/top/axi4lite_tb_top.sv` dumps `axi4lite_tb.vcd` when run with
`+DUMP` (e.g. `vsim ... +DUMP` or, for a Verilator-based flow,
`$test$plusargs("DUMP")` is honored the same way if you build a
`--trace` binary and pass `+DUMP` at runtime).
