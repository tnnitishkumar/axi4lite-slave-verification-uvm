# =============================================================================
# Makefile : AXI4-Lite Slave Verification (UVM)
#
# Primary flow targets Questa (vlog/vsim), which is the intended simulator
# for the full UVM environment. A Verilator-based RTL-only flow is provided
# as a fallback for environments without a licensed UVM-capable simulator
# (see docs/known_limitations.md for why Verilator/Icarus cannot run the
# full UVM stack).
#
# Usage:
#   make compile          # Questa: compile RTL + SVA + UVM TB
#   make smoke             # Questa: run axi4lite_smoke_test
#   make test TEST=<name>  # Questa: run a specific UVM test
#   make directed           # Questa: run every directed test
#   make regression         # Questa: run full_regression + random tests, N seeds
#   make clean
#
#   make rtl_sanity          # Verilator: RTL-only functional sanity (no UVM)
#   make rtl_lint             # Verilator: lint RTL + SVA
# =============================================================================

UVM_HOME       ?= $(QUESTA_UVM_HOME)
VSIM           ?= vsim
VLOG           ?= vlog
VOPT           ?= vopt
VERILATOR      ?= verilator

RTL_DIR    = ../../rtl
SVA_DIR    = ../../sva
TB_DIR     = ../../tb
LOG_DIR    = ../logs

RTL_SRCS = $(RTL_DIR)/axi4lite_pkg.sv \
           $(RTL_DIR)/axi4lite_if.sv \
           $(RTL_DIR)/axi4lite_slave.sv

SVA_SRCS = $(SVA_DIR)/axi4lite_protocol_sva.sv

TB_SRCS  = $(TB_DIR)/axi4lite_uvm_pkg.sv \
           $(TB_DIR)/top/axi4lite_tb_top.sv

WORKLIB  = work

TEST     ?= axi4lite_smoke_test
SEED     ?= 1
VERBOSITY ?= UVM_MEDIUM

# -----------------------------------------------------------------------
# Questa flow
# -----------------------------------------------------------------------
.PHONY: compile
compile:
	@mkdir -p $(LOG_DIR)
	@if [ -z "$(UVM_HOME)" ]; then \
		echo "ERROR: UVM_HOME / QUESTA_UVM_HOME is not set."; \
		echo "       Point it at the UVM library shipped with your Questa install,"; \
		echo "       e.g. export QUESTA_UVM_HOME=\$$MTI_HOME/verilog_src/uvm-1.2"; \
		exit 1; \
	fi
	vlib $(WORKLIB)
	$(VLOG) -sv -mfcu -work $(WORKLIB) +incdir+$(UVM_HOME) \
		$(RTL_SRCS) $(SVA_SRCS) \
		+incdir+$(TB_DIR)/env +incdir+$(TB_DIR)/agent \
		+incdir+$(TB_DIR)/sequences +incdir+$(TB_DIR)/tests \
		$(TB_SRCS) | tee $(LOG_DIR)/compile.log
	@echo "Compile complete. Log: $(LOG_DIR)/compile.log"

.PHONY: test
test: compile
	$(VSIM) -c -work $(WORKLIB) axi4lite_tb_top \
		+UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=$(VERBOSITY) -sv_seed $(SEED) \
		-do "run -all; quit -f" | tee $(LOG_DIR)/$(TEST)_seed$(SEED).log

.PHONY: smoke
smoke:
	$(MAKE) test TEST=axi4lite_smoke_test

.PHONY: directed
directed: compile
	@for t in axi4lite_reset_test axi4lite_single_rw_test axi4lite_multiple_rw_test \
	          axi4lite_back_to_back_test axi4lite_independent_aw_w_test \
	          axi4lite_wstrb_partial_test axi4lite_invalid_addr_test \
	          axi4lite_bready_backpressure_test axi4lite_rready_backpressure_test \
	          axi4lite_slave_stall_test axi4lite_corner_case_test; do \
		echo "=== Running $$t ==="; \
		$(VSIM) -c -work $(WORKLIB) axi4lite_tb_top \
			+UVM_TESTNAME=$$t +UVM_VERBOSITY=$(VERBOSITY) \
			-do "run -all; quit -f" | tee $(LOG_DIR)/$$t.log ; \
	done

.PHONY: regression
regression: compile
	@for seed in 1 2 3 4 5; do \
		echo "=== Random regression seed $$seed ==="; \
		$(VSIM) -c -work $(WORKLIB) axi4lite_tb_top \
			+UVM_TESTNAME=axi4lite_full_regression_test +UVM_VERBOSITY=UVM_LOW \
			-sv_seed $$seed -do "run -all; quit -f" \
			| tee $(LOG_DIR)/regression_seed$$seed.log ; \
	done

.PHONY: clean
clean:
	rm -rf $(WORKLIB) transcript vsim.wlf *.log $(LOG_DIR)/*.log

# -----------------------------------------------------------------------
# Verilator RTL-only fallback (no UVM - see docs/known_limitations.md)
# -----------------------------------------------------------------------
.PHONY: rtl_lint
rtl_lint:
	$(VERILATOR) --lint-only -Wall --timing -sv \
		$(RTL_SRCS) $(SVA_SRCS) --top-module axi4lite_slave

.PHONY: rtl_sanity
rtl_sanity:
	@mkdir -p /tmp/axi4lite_rtl_sanity_build
	$(VERILATOR) --binary --timing -Wno-fatal -sv --top-module rtl_sanity_tb \
		$(RTL_SRCS) $(SVA_SRCS) rtl_sanity_tb.sv \
		-o rtl_sanity_sim --Mdir /tmp/axi4lite_rtl_sanity_build
	/tmp/axi4lite_rtl_sanity_build/rtl_sanity_sim
