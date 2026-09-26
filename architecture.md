# Architecture — AXI4-Lite Slave

## 1. RTL Overview

`rtl/axi4lite_slave.sv` implements an AXI4-Lite slave with:

- 32-bit `AWADDR`/`ARADDR`, 32-bit `WDATA`/`RDATA`.
- 16 word-aligned, 32-bit memory-mapped registers (`NUM_REGS` in
  `axi4lite_pkg.sv`, addresses `0x00`-`0x3C`).
- Byte-granular writes via `WSTRB`.
- OKAY (`2'b00`) for valid, word-aligned, in-range accesses; SLVERR
  (`2'b10`) for out-of-range or unaligned accesses (on both the B and R
  channels).

## 2. Independent AW/W Channel Handling

Per the AXI4 spec, a slave must not assume AWVALID and WVALID arrive
together. The DUT tracks each channel with its own one-deep "pending"
latch:

```
aw_pending  - set when AWVALID & AWREADY fire and the write hasn't
              committed yet; AWREADY = ARESETn & ~aw_pending
w_pending   - the same, for WVALID/WREADY
```

A write **commits** (updates the register file and asserts BVALID) as
soon as *both* an address and data are available - whether that's
because they arrived on the same cycle, or because one was already
latched from an earlier cycle:

```systemverilog
wire do_write_commit = (aw_pending || aw_hs) && (w_pending || w_hs)
                        && (!bvalid_q || b_hs);
```

**Design note (bug found and fixed during bring-up):** the pending-latch
flops must give the "clear on commit" branch priority over the "capture
as pending" branch. The first version of this RTL did the opposite, so
when AW and W arrived on the *same* cycle and the write committed
immediately, `aw_pending`/`ar_pending` would incorrectly latch to `1`
forever, permanently deadlocking `AWREADY`/`ARREADY`. This was caught by
`sim/scripts/rtl_sanity_tb.sv` (see `docs/known_limitations.md` /
commit history for the fix) and is exactly the class of corner case
`axi4lite_independent_aw_w_test` and `axi4lite_slave_stall_test` target.

The read address channel (`ar_pending`) uses the identical pattern for
symmetry, even though AXI4-Lite reads only have one address channel to
begin with - it keeps the "commit always takes priority" rule
consistent across both directions.

## 3. Response Generation

`BVALID`/`RVALID` are single-outstanding (one response in flight at a
time; a second write cannot commit until the previous `BVALID` has been
accepted via `BREADY`, per `do_write_commit`'s `(!bvalid_q || b_hs)`
term). `BRESP`/`RRESP` are computed combinationally from the committing
address (`commit_addr_in_range` / `read_addr_in_range`, plain
combinational wires - see the note below) and registered alongside
`BVALID`/`RVALID`.

**Design note:** address-range decode was originally a `function
automatic`. During bring-up this produced inconsistent results between
call sites under the same simulator/timing mode (see
`docs/known_limitations.md`), even though the function's logic was
correct in isolation. It was replaced with plain combinational wires
(`commit_addr_in_range`, `read_addr_in_range`), which is both simpler
to reason about and more portable across simulators.

## 4. Verification Environment Architecture

```
tb/top/axi4lite_tb_top.sv
  |- axi4lite_if              (clocking blocks for driver/monitor, plain
  |                            signal modport for the SVA checker)
  |- axi4lite_slave  (DUT)
  |- axi4lite_protocol_sva    (bound alongside the DUT, always active)
  \- uvm_config_db#(virtual axi4lite_if)::set(...) + run_test()

axi4lite_env
  |- axi4lite_agent (UVM_ACTIVE)
  |    |- axi4lite_sequencer
  |    |- axi4lite_driver     (drives AW/W as two independent fork
  |    |                       branches per transaction; independent
  |    |                       BREADY/RREADY backpressure delays)
  |    \- axi4lite_monitor    (independently tracks AW and W handshakes,
  |                            publishes one txn per completed write or
  |                            read to an analysis port)
  |- axi4lite_scoreboard       (shadow register-file reference model)
  \- axi4lite_coverage         (functional coverage, subscriber)
```

Sequences (`tb/sequences/axi4lite_seq_lib.sv`) generate
`axi4lite_transaction` items; the driver converts them to pin-level
activity; the monitor reconstructs completed transactions from pin
activity and fans them out to the scoreboard and coverage collector.
This is the standard UVM layered structure, sized appropriately for a
single-DUT, single-interface environment (one agent is sufficient here -
there's only one bus).

## 5. Directory Layout

See `docs/project_structure.md`.
