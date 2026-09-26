# Verification Plan — AXI4-Lite Slave

## 1. Objective

Verify the `axi4lite_slave` RTL (`rtl/axi4lite_slave.sv`) implements a
protocol-compliant AXI4-Lite slave with 16 memory-mapped 32-bit registers,
correct WSTRB byte-enable behavior, correct independent handling of the
AW and W channels, and correct OKAY/SLVERR responses.

## 2. DUT Feature List (from the RTL)

| # | Feature                                             | Source |
|---|------------------------------------------------------|--------|
| 1 | 32-bit address, 32-bit data                           | `axi4lite_pkg.sv` |
| 2 | 16 word-aligned memory-mapped registers                | `axi4lite_pkg.sv::NUM_REGS` |
| 3 | Independent AW/W channel arrival (any order/timing)     | `axi4lite_slave.sv` aw_pending/w_pending logic |
| 4 | WSTRB byte-lane write enables                            | `axi4lite_slave.sv` commit loop |
| 5 | Synchronous active-low reset clears all state             | `always_ff ... !ARESETn` blocks |
| 6 | OKAY response for valid, aligned, in-range accesses         | `commit_addr_in_range` / `read_addr_in_range` |
| 7 | SLVERR response for out-of-range or unaligned accesses        | same |

## 3. Verification Strategy

- **RTL-level directed sanity** (`sim/scripts/rtl_sanity_tb.sv`, non-UVM):
  fast, dependency-free correctness check runnable with Verilator alone.
  Used throughout RTL development; all 21 checks currently pass.
- **UVM environment** (`tb/`): full class-based environment with a
  reference-model scoreboard and functional coverage, intended for Questa/
  VCS/Xcelium. See `docs/known_limitations.md` for why this cannot be
  executed with the open-source tools available in this environment.
- **SVA** (`sva/axi4lite_protocol_sva.sv`): bound alongside the DUT in
  both the RTL sanity TB and the UVM TB top, continuously checking
  protocol rules independent of any one test's checks.

## 4. Features to Verify → How

| Feature | Directed test(s) | Random coverage | SVA |
|---|---|---|---|
| Reset behavior | `axi4lite_reset_test` | n/a | `a_reset_clears_ready` |
| Single write / read | `axi4lite_single_rw_test` | `cp_dir`, `cp_reg_addr` | handshake stability asserts |
| Multiple read/write | `axi4lite_multiple_rw_test` | `cp_reg_addr` (all 16 regs) | - |
| Back-to-back transactions | `axi4lite_back_to_back_test` | random sequence | - |
| Independent AW/W arrival | `axi4lite_independent_aw_w_test` | `cp_aw_w_order` | AW/W VALID stability asserts |
| WSTRB partial writes | `axi4lite_wstrb_partial_test` | `cp_wstrb` | - |
| Invalid / unaligned addresses | `axi4lite_invalid_addr_test` | `cp_reg_addr::out_of_range`, `cp_bresp`/`cp_rresp::slverr` | `a_bresp_legal`, `a_rresp_legal` |
| BREADY backpressure | `axi4lite_bready_backpressure_test` | `cp_bready_delay` | `a_bvalid_stable` |
| RREADY backpressure | `axi4lite_rready_backpressure_test` | `cp_rready_delay` | `a_rvalid_stable` |
| AWREADY/WREADY/ARREADY stall | `axi4lite_slave_stall_test` | (implicit, any back-to-back item) | `a_awvalid_stable`, `a_arvalid_stable`, deadlock counters |
| Corner cases (first/last reg, one-past-end, max skew+backpressure) | `axi4lite_corner_case_test` | - | - |
| General random traffic | `axi4lite_random_test` | full `cg_transaction` covergroup | all of the above |

## 5. Checking Strategy

The scoreboard (`tb/env/axi4lite_scoreboard.sv`) is a reference model that:
1. Maintains a shadow copy of the DUT's 16-register file.
2. On every observed **write**, checks BRESP is OKAY iff the address is
   word-aligned and in `[0, NUM_REGS)`, otherwise SLVERR; if OKAY, applies
   the write to the shadow model respecting WSTRB.
3. On every observed **read**, checks RRESP the same way, and checks
   RDATA against the shadow model (or `0` for an out-of-range read, per
   the RTL's defined behavior).
4. Reports a pass/fail summary in `report_phase`.

SVA assertions (`sva/axi4lite_protocol_sva.sv`) check protocol-level
rules independent of any specific test's stimulus: VALID/payload
stability until READY on all five channels, response-encoding legality,
reset behavior, and a bounded-wait deadlock check on AWVALID/ARVALID.

## 6. Coverage Closure Criteria (target, for a Questa/VCS run)

- 100% of `cp_dir`, `cp_reg_addr` (all 16 regs + out-of-range), `cp_wstrb`,
  `cp_bresp`, `cp_rresp` bins hit.
- 100% of `cp_aw_w_order` bins (same-cycle, AW-first, W-first) hit.
- `cp_bready_delay` / `cp_rready_delay` all three buckets (none/short/long) hit.
- `cx_dir_resp` cross fully hit (every legal dir x bresp x rresp combination
  reachable in this protocol subset).
- 0 scoreboard errors, 0 SVA assertion failures across the full
  directed-plus-random regression (`make regression`, 5 seeds minimum).

## 7. Known Gap

This plan and environment were fully authored and structurally validated
(see `docs/known_limitations.md`), but **not executed as UVM** in this
environment due to open-source tool limitations. The RTL itself was
validated against an equivalent, independently-written directed
testbench (`sim/scripts/rtl_sanity_tb.sv`) covering the same scenario
list, and passes today.
