# FPGA Common Makefile Rules for Intel 8008 Vintage CPU Project
# Include this file in project-specific Makefiles
#
# Required project-specific variables:
#   TOP_ENTITY      - Top-level entity name
#   TB_ENTITY       - Testbench entity name (or default testbench if TEST not specified)
#   RTL_SOURCES     - List of RTL source files
#   TB_SOURCES      - List of testbench files (optional, for single test)
#   ALL_TB_SOURCES  - List of all testbench files (optional, for multiple tests)
#
# Optional overrides:
#   TEST            - Specify which test to run (e.g., make sim TEST=alu_test)
#   SIM_STOP_TIME   - Simulation duration (default: 1ms)
#   FPGA_DEVICE     - FPGA device (default: um5g-45k for ECP5)
#   FPGA_PACKAGE    - Package type (default: CABGA381)
#   FPGA_SPEED      - Speed grade (default: 8)

#==========================================
# Environment Setup
#==========================================
# Load environment variables from .env if it exists
-include $(dir $(lastword $(MAKEFILE_LIST))).env

# Default username (override in .env)
USERNAME ?= hackbook

# OSS CAD Suite path
OSS_CAD_SUITE ?= /Users/$(USERNAME)/oss-cad-suite
SHELL := /bin/bash
export PATH := $(OSS_CAD_SUITE)/bin:$(PATH)

#==========================================
# Tools
#==========================================
GHDL = $(OSS_CAD_SUITE)/bin/ghdl
YOSYS = $(OSS_CAD_SUITE)/bin/yosys
NEXTPNR = $(OSS_CAD_SUITE)/bin/nextpnr-ecp5
ECPPACK = $(OSS_CAD_SUITE)/bin/ecppack
OPENFPGALOADER = $(OSS_CAD_SUITE)/bin/openFPGALoader
GTKWAVE = $(OSS_CAD_SUITE)/bin/gtkwave

#==========================================
# Directories
#==========================================
SRC_DIR = src
SIM_DIR = sim
BUILD_DIR = build
WORK_DIR = work
CONSTRAINTS_DIR = constraints
REPORTS_DIR = reports

#==========================================
# FPGA Configuration
#==========================================
# Lattice ECP5-5G Versa board defaults (LFE5UM5G-45F-VERSA-EVN)
FPGA_DEVICE ?= um5g-45k
FPGA_PACKAGE ?= CABGA381
FPGA_SPEED ?= 8

#==========================================
# Build outputs
#==========================================
LPF_FILE = $(CONSTRAINTS_DIR)/versa_ecp5.lpf
JSON_FILE = $(BUILD_DIR)/$(TOP_ENTITY).json
TEXTCFG_FILE = $(BUILD_DIR)/$(TOP_ENTITY).config
BITSTREAM_FILE = $(BUILD_DIR)/$(TOP_ENTITY).bit

# Report files
SYNTH_REPORT = $(REPORTS_DIR)/synthesis.txt
PNR_REPORT = $(REPORTS_DIR)/pnr.txt
TIMING_REPORT = $(REPORTS_DIR)/timing.txt
UTILIZATION_REPORT = $(REPORTS_DIR)/utilization.txt
# Simulation report uses the active testbench name (set after ACTIVE_TB_ENTITY is determined)
SIM_REPORT = $(REPORTS_DIR)/sim_$(ACTIVE_TB_ENTITY).txt

#==========================================
# Simulation parameters
#==========================================
# If TEST is specified, override TB_ENTITY and TB_SOURCES
# Check both sim/ and sim/units/ directories for test files
ifdef TEST
    ACTIVE_TB_ENTITY = $(TEST)
    # Try units directory first, then main sim directory
    ifneq (,$(wildcard $(SIM_DIR)/units/$(TEST).vhdl))
        ACTIVE_TB_SOURCES = $(SIM_DIR)/units/$(TEST).vhdl
    else
        ACTIVE_TB_SOURCES = $(SIM_DIR)/$(TEST).vhdl
    endif
else
    ACTIVE_TB_ENTITY = $(TB_ENTITY)
    ACTIVE_TB_SOURCES = $(TB_SOURCES)
endif

# SIM_STOP_TIME is now set in the project-specific Makefile based on test
# Default fallback if not specified
SIM_STOP_TIME ?= 1ms
SIM_OUTPUT = $(SIM_DIR)/output.txt
WAVE_FILE = $(REPORTS_DIR)/$(ACTIVE_TB_ENTITY).ghw
GTKW_FILE = $(SIM_DIR)/$(ACTIVE_TB_ENTITY).gtkw
GHDL_FLAGS ?= --std=08

#==========================================
# Default Targets
#==========================================
.PHONY: all
all: sim

#==========================================
# Directory Creation
#==========================================
$(WORK_DIR):
	@mkdir -p $(WORK_DIR)

$(BUILD_DIR):
	@mkdir -p $@

# Note: reports directory creation (avoid naming conflict with .PHONY target)
.PHONY: create-reports-dir
create-reports-dir:
	@mkdir -p $(REPORTS_DIR)

#==========================================
# Simulation Flow
#==========================================

# Analyze RTL sources
.PHONY: analyze-rtl
analyze-rtl: $(WORK_DIR)
	@echo "Analyzing RTL sources..."
	$(GHDL) -a $(GHDL_FLAGS) --workdir=$(WORK_DIR) $(RTL_SOURCES)

# Analyze testbench sources
.PHONY: analyze-tb
analyze-tb: analyze-rtl
	@echo "Analyzing testbench sources..."
	$(GHDL) -a $(GHDL_FLAGS) --workdir=$(WORK_DIR) $(ACTIVE_TB_SOURCES)

# Elaborate (build) testbench
.PHONY: elaborate
elaborate: analyze-tb
	@echo "Elaborating $(ACTIVE_TB_ENTITY)..."
	$(GHDL) -e $(GHDL_FLAGS) --workdir=$(WORK_DIR) $(ACTIVE_TB_ENTITY)

# Run simulation, generate GHW, and optionally open GTKWave
# Use WAVE=1 to launch GTKWave after simulation: make sim WAVE=1
.PHONY: sim
sim: elaborate | create-reports-dir
	@echo "Running simulation with GHW output..."
	@echo "==========================================" > $(SIM_REPORT)
	@echo "Simulation Report - $(shell date)" >> $(SIM_REPORT)
	@echo "Testbench: $(ACTIVE_TB_ENTITY)" >> $(SIM_REPORT)
	@echo "==========================================" >> $(SIM_REPORT)
	@echo "" >> $(SIM_REPORT)
	@set -o pipefail; $(GHDL) -r $(GHDL_FLAGS) --workdir=$(WORK_DIR) $(ACTIVE_TB_ENTITY) \
		--stop-time=$(SIM_STOP_TIME) \
		--wave=$(WAVE_FILE) \
		--assert-level=error \
		--ieee-asserts=disable-at-0 \
		2>&1 | tee -a $(SIM_REPORT); \
	SIM_EXIT=$$?; \
	echo "" >> $(SIM_REPORT); \
	if [ $$SIM_EXIT -eq 0 ]; then \
		echo "✓ SIMULATION PASSED - No assertion violations" | tee -a $(SIM_REPORT); \
		echo "GHW file saved to $(WAVE_FILE)"; \
		echo "Report saved to $(SIM_REPORT)"; \
		if [ "$(WAVE)" = "1" ]; then \
			echo "Launching GTKWave..."; \
			$(GTKWAVE) $(WAVE_FILE) $(GTKW_FILE) & \
		fi; \
	else \
		echo "✗ SIMULATION FAILED - Assertion violations detected!" | tee -a $(SIM_REPORT); \
		echo "Report saved to $(SIM_REPORT)"; \
		if [ "$(WAVE)" = "1" ]; then \
			echo "Launching GTKWave for debugging..."; \
			$(GTKWAVE) $(WAVE_FILE) $(GTKW_FILE) & \
		fi; \
		exit $$SIM_EXIT; \
	fi

#==========================================
# FPGA Synthesis Flow
#==========================================

# Synthesis: VHDL -> JSON netlist (using GHDL synth)
$(JSON_FILE): $(RTL_SOURCES) | $(BUILD_DIR) create-reports-dir
	@echo "Analyzing VHDL for synthesis..."
	$(GHDL) -a $(GHDL_FLAGS) $(RTL_SOURCES)
	@echo "Synthesizing with GHDL and Yosys..."
	$(GHDL) --synth $(GHDL_FLAGS) --out=verilog $(TOP_ENTITY) > $(BUILD_DIR)/$(TOP_ENTITY).v
	@echo "Running Yosys synthesis..."
	$(YOSYS) -p "read_verilog $(BUILD_DIR)/$(TOP_ENTITY).v; synth_ecp5 -top $(TOP_ENTITY) -json $(JSON_FILE)" 2>&1 | tee $(SYNTH_REPORT)
	@echo "Synthesis report saved to $(SYNTH_REPORT)"


# Place & Route: JSON -> config file
$(TEXTCFG_FILE): $(JSON_FILE) | create-reports-dir
	@echo "Running place and route..."
	@if [ -f "$(LPF_FILE)" ]; then \
		$(NEXTPNR) --$(FPGA_DEVICE) --package $(FPGA_PACKAGE) --speed $(FPGA_SPEED) \
			--json $(JSON_FILE) --textcfg $(TEXTCFG_FILE) --lpf $(LPF_FILE) --lpf-allow-unconstrained \
			2>&1 | tee $(PNR_REPORT); \
	else \
		echo "Warning: No constraints file found at $(LPF_FILE)"; \
		echo "Running without pin constraints..."; \
		$(NEXTPNR) --$(FPGA_DEVICE) --package $(FPGA_PACKAGE) --speed $(FPGA_SPEED) \
			--json $(JSON_FILE) --textcfg $(TEXTCFG_FILE) \
			2>&1 | tee $(PNR_REPORT); \
	fi
	@echo "Place and route report saved to $(PNR_REPORT)"
	@echo ""
	@echo "Extracting timing report..."
	@grep -A 50 "Critical path report" $(PNR_REPORT) > $(TIMING_REPORT) || true
	@grep "Max frequency\|Max delay\|Slack" $(PNR_REPORT) >> $(TIMING_REPORT) || true
	@echo "Timing report saved to $(TIMING_REPORT)"
	@echo ""
	@echo "Extracting utilization report..."
	@grep -B 2 -A 30 "Device utilisation" $(PNR_REPORT) > $(UTILIZATION_REPORT) || true
	@echo "Utilization report saved to $(UTILIZATION_REPORT)"


# Pack: config -> bitstream
$(BITSTREAM_FILE): $(TEXTCFG_FILE)
	@echo "Generating bitstream..."
	$(ECPPACK) $(TEXTCFG_FILE) $(BITSTREAM_FILE)

.PHONY: bitstream
bitstream: $(BITSTREAM_FILE)

# Program to FPGA SRAM (volatile, fast for testing)
.PHONY: program
program: $(BITSTREAM_FILE)
	@echo "Programming FPGA SRAM (volatile)..."
	$(OPENFPGALOADER) -c ft2232 -m $(BITSTREAM_FILE)

# Program to FPGA flash (persistent, survives power cycle)
.PHONY: flash
flash: $(BITSTREAM_FILE)
	@echo "Programming FPGA flash (persistent)..."
	$(OPENFPGALOADER) -b versa_ecp5 $(BITSTREAM_FILE)

#==========================================
# Utility Targets
#==========================================

# List available tests
.PHONY: list-tests
list-tests:
	@echo "Available testbenches:"
	@if [ -n "$(ALL_TB_SOURCES)" ]; then \
		for tb in $(ALL_TB_SOURCES); do \
			name=$$(basename $$tb .vhdl); \
			echo "  - $$name"; \
		done; \
		echo ""; \
		echo "Usage: make sim TEST=<testbench_name>"; \
		echo "Example: make sim TEST=$$(basename $(word 1,$(ALL_TB_SOURCES)) .vhdl)"; \
	else \
		echo "  - $(TB_ENTITY) (default)"; \
	fi

# View simulation report (for last run test, or specify TEST=name)
.PHONY: sim-report
sim-report:
	@if [ ! -f "$(SIM_REPORT)" ]; then \
		echo "No simulation report found for $(ACTIVE_TB_ENTITY)."; \
		echo "Available reports:"; \
		ls -1 $(REPORTS_DIR)/sim_*.txt 2>/dev/null | sed 's/.*sim_/  - /' | sed 's/.txt//' || echo "  (none)"; \
		echo ""; \
		echo "Run 'make sim' or 'make sim TEST=<name>' first."; \
		exit 1; \
	fi
	@cat $(SIM_REPORT)

# View build reports
.PHONY: reports
reports:
	@if [ ! -d "$(REPORTS_DIR)" ]; then \
		echo "No reports found. Run 'make bitstream' first."; \
		exit 1; \
	fi
	@echo "=========================================="
	@echo "FPGA Build Reports"
	@echo "=========================================="
	@echo ""
	@if [ -f "$(UTILIZATION_REPORT)" ]; then \
		echo "--- Resource Utilization ---"; \
		cat $(UTILIZATION_REPORT); \
		echo ""; \
	fi
	@if [ -f "$(TIMING_REPORT)" ]; then \
		echo "--- Timing Summary ---"; \
		head -20 $(TIMING_REPORT); \
		echo ""; \
	fi
	@echo "Full reports available at:"
	@echo "  Simulation Reports:"
	@ls -1 $(REPORTS_DIR)/sim_*.txt 2>/dev/null | sed 's|$(REPORTS_DIR)/|    |' || echo "    (no simulation reports)"
	@echo "  Waveform Files:"
	@ls -1 $(REPORTS_DIR)/*.ghw 2>/dev/null | sed 's|$(REPORTS_DIR)/|    |' || echo "    (no waveform files)"
	@echo "  Synthesis:    $(SYNTH_REPORT)"
	@echo "  PnR:          $(PNR_REPORT)"
	@echo "  Timing:       $(TIMING_REPORT)"
	@echo "  Utilization:  $(UTILIZATION_REPORT)"

# Clean generated files
.PHONY: clean
clean:
	@echo "Cleaning simulation files..."
	@$(GHDL) --clean $(GHDL_FLAGS) --workdir=$(WORK_DIR) 2>/dev/null || true
	@rm -rf $(WORK_DIR)
	@rm -f $(TB_ENTITY) $(ACTIVE_TB_ENTITY)
	@rm -f *.cf
	@rm -f $(SIM_DIR)/*.vcd $(SIM_DIR)/*.ghw
	@rm -f $(REPORTS_DIR)/*.ghw

# Clean everything including FPGA build
.PHONY: clean-all distclean
clean-all distclean: clean
	@echo "Cleaning all build files..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(REPORTS_DIR)

# Help target
.PHONY: help
help:
	@echo "FPGA Build and Simulation Makefile - Intel 8008 Vintage CPU"
	@echo ""
	@echo "=== Primary Workflow ==="
	@echo "  make sim        - Run simulation and open GTKWave (default)"
	@echo "  make bitstream  - Build FPGA bitstream with reports"
	@echo "  make program    - Flash to FPGA SRAM (volatile, fast)"
	@echo "  make flash      - Flash to FPGA flash (persistent)"
	@echo ""
	@echo "=== Testing ==="
	@echo "  make list-tests - List all available testbenches"
	@echo "  make sim TEST=<name> - Run specific testbench"
	@if [ -n "$(ALL_TB_SOURCES)" ]; then \
		echo "  Example: make sim TEST=$$(basename $(word 1,$(ALL_TB_SOURCES)) .vhdl)"; \
	fi
	@echo ""
	@echo "=== Utility Targets ==="
	@echo "  make sim-report - View simulation report (assertions, warnings)"
	@echo "  make reports    - View synthesis/timing/utilization reports"
	@echo "  make clean      - Remove simulation files"
	@echo "  make clean-all  - Remove all build files and reports"
	@echo "  make help       - Show this help"
	@echo ""
	@echo "=== Advanced Options ==="
	@echo "  SIM_STOP_TIME   - Simulation duration (default: $(SIM_STOP_TIME))"
	@echo "  TEST            - Specify testbench to run"
	@echo "  Example: make sim SIM_STOP_TIME=2ms TEST=alu_test"
	@echo ""
	@echo "=== Typical Workflow ==="
	@echo "  1. make sim         # Verify design in simulation"
	@echo "  2. make bitstream   # Synthesize for FPGA"
	@echo "  3. make reports     # Check timing/utilization"
	@echo "  4. make program     # Flash to SRAM (test)"
	@echo "  5. make flash       # Flash to persistent memory (deploy)"
