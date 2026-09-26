# Test Plan — AXI4-Lite Slave

Each row is a concrete test in the UVM environment (`tb/tests/axi4lite_test_lib.sv`),
backed by a sequence in `tb/sequences/axi4lite_seq_lib.sv`. Every directed
test has a **directly corresponding scenario already proven, standalone,
against the same RTL** in `sim/scripts/rtl_sanity_tb.sv` (see that file's
T1-T10 for the mapping) - this table's "RTL sanity equivalent" column
gives the cross-reference.

| UVM Test | Sequence | What it checks | RTL sanity equivalent |
|---|---|---|---|
| `axi4lite_smoke_test` | `axi4lite_single_rw_seq` | Fast sanity: one write, one read-back | T1 |
| `axi4lite_reset_test` | `axi4lite_single_rw_seq` x2 + mid-test reset pulse | Bus functional before and after an ARESETn pulse; all state cleared | T10 |
| `axi4lite_single_rw_test` | `axi4lite_single_rw_seq` | Single write then read-back, data integrity | T1 |
| `axi4lite_multiple_rw_test` | `axi4lite_multiple_rw_seq` | Writes/reads to every one of the 16 registers | T7 (extended) |
| `axi4lite_back_to_back_test` | `axi4lite_back_to_back_seq` | Zero-gap consecutive writes then reads | T7 |
| `axi4lite_independent_aw_w_test` | `axi4lite_independent_aw_w_seq` | AW-before-W, W-before-AW, and same-cycle arrival | T2, T3 |
| `axi4lite_wstrb_partial_test` | `axi4lite_wstrb_partial_seq` | All single-byte and half-word WSTRB patterns | T4 |
| `axi4lite_invalid_addr_test` | `axi4lite_invalid_addr_seq` | Out-of-range and unaligned addresses -> SLVERR | T5, T6 |
| `axi4lite_bready_backpressure_test` | `axi4lite_bready_backpressure_seq` | BVALID held stable while BREADY withheld | T8 |
| `axi4lite_rready_backpressure_test` | `axi4lite_rready_backpressure_seq` | RVALID held stable while RREADY withheld | T9 |
| `axi4lite_slave_stall_test` | `axi4lite_slave_stall_seq` | Back-to-back items force the driver to wait on AWREADY/WREADY/ARREADY while the slave is still committing a prior transaction | (new - exercises the DUT's `aw_pending`/`w_pending`/`ar_pending` stall paths directly) |
| `axi4lite_corner_case_test` | `axi4lite_corner_case_seq` | First/last valid register, one-past-the-end, max independent-arrival skew combined with max backpressure, single-byte WSTRB at the boundary register | T5-T9 combined at the edges |
| `axi4lite_random_test` | `axi4lite_random_seq` | Constrained-random mix of everything above, 20-200 transactions per run | all of the above, generalized |
| `axi4lite_full_regression_test` | all sequences above, run in one test | "Run everything" target for a single invocation | all of the above |

## Pass/Fail Criteria (every test)

A test passes iff, by the end of `report_phase`:
1. The scoreboard reports `SCOREBOARD: ALL CHECKS PASSED` (0 mismatches
   between observed BRESP/RRESP/RDATA and the reference model).
2. No SVA assertion in `axi4lite_protocol_sva.sv` fired an error.
3. No `UVM_ERROR` or `UVM_FATAL` was logged (checked automatically by
   `axi4lite_base_test::report_phase`, which prints `TEST RESULT: PASS`
   or `TEST RESULT: FAIL`).
4. The test completed before the 50 us global watchdog in
   `axi4lite_base_test::run_phase`.

## Regression

`make regression` (see `sim/scripts/Makefile`) runs
`axi4lite_full_regression_test` across 5 random seeds. `make directed`
runs every directed test once. `make smoke` runs just the smoke test for
a fast sanity check in CI.
