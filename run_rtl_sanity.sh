#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# run_rtl_sanity.sh
#
# Runs the RTL-only, non-UVM directed sanity testbench through Verilator.
# This is the flow that was actually built and executed while developing
# this project (see docs/known_limitations.md for why the full UVM
# environment cannot currently be executed with open-source tools, and
# docs/simulation_instructions.md for the intended Questa flow).
#
# Usage: ./run_rtl_sanity.sh
# Exit code: 0 if "ALL TESTS PASSED" appeared in the output, 1 otherwise.
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$(mktemp -d)"
LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

echo "== Linting RTL + SVA =="
verilator --lint-only -Wall -Wno-fatal --timing -sv \
    "$PROJECT_ROOT/rtl/axi4lite_pkg.sv" \
    "$PROJECT_ROOT/rtl/axi4lite_if.sv" \
    "$PROJECT_ROOT/rtl/axi4lite_slave.sv" \
    "$PROJECT_ROOT/sva/axi4lite_protocol_sva.sv" \
    --top-module axi4lite_slave
echo "(lint warnings above are expected/cosmetic - unused ports on the"
echo " interface's plain-signal modports when only axi4lite_slave is"
echo " elaborated standalone; see docs/known_limitations.md)"

echo "== Building RTL sanity simulation =="
verilator --binary --timing -Wno-fatal -sv --top-module rtl_sanity_tb \
    "$PROJECT_ROOT/rtl/axi4lite_pkg.sv" \
    "$PROJECT_ROOT/rtl/axi4lite_if.sv" \
    "$PROJECT_ROOT/rtl/axi4lite_slave.sv" \
    "$PROJECT_ROOT/sva/axi4lite_protocol_sva.sv" \
    "$SCRIPT_DIR/rtl_sanity_tb.sv" \
    -o rtl_sanity_sim --Mdir "$BUILD_DIR"

echo "== Running RTL sanity simulation =="
OUT_LOG="$LOG_DIR/rtl_sanity_run.log"
"$BUILD_DIR/rtl_sanity_sim" | tee "$OUT_LOG"

if grep -q "ALL TESTS PASSED" "$OUT_LOG"; then
    echo "RESULT: PASS"
    exit 0
else
    echo "RESULT: FAIL"
    exit 1
fi
