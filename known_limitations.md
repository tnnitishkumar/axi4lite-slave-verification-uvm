# Known Limitations

## 1. No licensed UVM-capable simulator was available in this environment

This project was built in a sandboxed Linux container with no Questa,
VCS, or Xcelium license, and no network access other than a short
allow-list of package/source-hosting domains. The two open-source
simulators available (Icarus Verilog 12.0 and Verilator 5.020, both
installed via `apt-get` for this project) were evaluated as substitutes
and **both have specific, reproducible limitations that block running
the full UVM environment**, documented below with the actual command
and error output that was captured while building this project. Logs
are checked in under `sim/logs/`.

This is the same class of blocker the project brief anticipated for a
Questa license limitation; per the brief's instruction, **the UVM
environment was not weakened or simplified to work around this** - it is
written as complete, idiomatic UVM-1.2/1800.2 code throughout, targeting
Questa/VCS/Xcelium as the intended simulators (see
`docs/simulation_instructions.md`).

### 1.1 Icarus Verilog cannot parse SystemVerilog interface clocking blocks

The driver and monitor use `axi4lite_if`'s `drv_cb`/`mon_cb` clocking
blocks (`rtl/axi4lite_if.sv`), which is the correct, standard, race-free
way to write a UVM driver/monitor against a virtual interface. Icarus
Verilog 12.0 fails to parse a `clocking ... endclocking` block declared
inside an `interface`:

```
$ iverilog -g2012 -o /tmp/x.out rtl/axi4lite_pkg.sv rtl/axi4lite_if.sv
rtl/axi4lite_if.sv:90: syntax error
rtl/axi4lite_if.sv:90: error: Invalid module item.
rtl/axi4lite_if.sv:101: syntax error
...
```
(full output in `sim/logs/iverilog_clocking_block_blocker.log`)

Icarus Verilog was therefore not usable for the UVM testbench at all
(it was also not usable earlier for even the plain RTL + SVA sanity
testbench, for the same reason - see `sim/scripts/run_rtl_sanity.sh`,
which uses Verilator exclusively).

### 1.2 Verilator cannot elaborate the Accellera UVM base library itself

Verilator 5.020 was tried against the official Accellera
`uvm-core` library (tag `2020.3.1`, i.e. IEEE 1800.2 UVM, a superset of
UVM-1.2), fetched directly from
`https://github.com/accellera-official/uvm-core` for this evaluation.
Even a bare, unmodified `uvm_pkg.sv` with no project code involved fails
to elaborate - UVM's own internal `uvm_coreservice.svh` uses a
`type_id::create()` factory call pattern that Verilator's `--lint-only`
elaborator rejects:

```
$ verilator --lint-only -Wno-fatal --timing -sv +incdir+<uvm_home> \
    +incdir+<uvm_home>/base +incdir+<uvm_home>/macros \
    +define+UVM_NO_DPI +define+UVM_NO_DEPRECATED \
    <uvm_home>/uvm_pkg.sv --top-module uvm_pkg

%Error-PKGNODECL: uvm_coreservice.svh:379:42: Package/class 'type_id' not
  found, and needs to be predeclared (IEEE 1800-2017 26.3)
            m_hopper = uvm_phase_hopper::type_id::create("default_hopper");
```
(full output in `sim/logs/verilator_uvm_library_blocker.log`)

This is a limitation of Verilator's support for the UVM base library's
class/factory patterns, not of this project's code - the error is
entirely inside UVM's own source, before any of this project's files
are even reached.

### 1.3 Verilator does not implement SystemVerilog covergroups

Independent of the UVM library issue above, Verilator does not support
`covergroup`/`coverpoint` at all:

```
$ verilator --lint-only -Wno-fatal --timing -sv tb/env/axi4lite_coverage.sv ...
%Error-UNSUPPORTED: tb/env/axi4lite_coverage.sv:20:5: Unsupported: covergroup
%Error-UNSUPPORTED: tb/env/axi4lite_coverage.sv:21:9: Unsupported: coverage option
%Error-UNSUPPORTED: tb/env/axi4lite_coverage.sv:23:18: Unsupported: cover point
...
```
(full output in `sim/logs/verilator_covergroup_blocker.log`)

This is a documented, long-standing architectural limitation of
Verilator (it has no native functional-coverage database), not a bug in
`axi4lite_coverage.sv`.

## 2. What was actually done instead

Given the above, verification effort was split two ways:

1. **The RTL was verified for real**, with a real, independently-written,
   non-UVM directed testbench (`sim/scripts/rtl_sanity_tb.sv`), compiled
   and run with Verilator (which *does* handle plain synthesizable RTL,
   interfaces without clocking-block-dependent code paths in the DUT
   itself, and immediate/concurrent SVA assertions on plain signals,
   all of which are used successfully in `sva/axi4lite_protocol_sva.sv`
   and the RTL sanity flow). This caught and fixed two real RTL bugs
   during development (see `docs/architecture.md` section 2 and 3) and
   currently passes all 21 directed checks - see
   `sim/scripts/run_rtl_sanity.sh` and its logged output.

2. **The UVM environment was written in full**, to the scope requested
   (transaction, sequencer, driver, monitor, agent, scoreboard,
   coverage, env, base test, 10 directed tests, 1 random test, 1
   full-regression test), targeting Questa/VCS/Xcelium via
   `sim/scripts/Makefile`'s primary flow. It was checked as far as the
   available tools allow:
   - Every `.sv` file was reviewed for structural balance (class/
     endclass, function/endfunction, task/endtask, begin/end all
     matched) file-by-file.
   - The RTL, package, and interface it's built against are the exact,
     already-verified files from step 1.
   - It was **not** possible to get a full compile/elaborate/simulate
     pass against real UVM in this environment, for the reasons in
     section 1. It has not been run, and this document does not claim
     otherwise.

## 3. What a user with Questa/VCS/Xcelium should expect

Point `QUESTA_UVM_HOME` (or `UVM_HOME`) at your simulator's bundled UVM-1.2
(or 1800.2) library and run `make compile && make smoke` from
`sim/scripts/`. Because the environment was written directly against
standard UVM-1.2/1800.2 APIs (`uvm_driver#(T)`, `uvm_monitor`,
`uvm_sequencer#(T)`, `uvm_scoreboard`, `uvm_subscriber#(T)`,
`uvm_config_db`, `covergroup`/`coverpoint`, clocking-block-based virtual
interface access) with no project-specific workarounds, it is expected
to compile and run normally on a standard UVM-capable simulator; this
has not been independently confirmed against a real license in this
environment and should be validated by the user's first `make compile`
run.
