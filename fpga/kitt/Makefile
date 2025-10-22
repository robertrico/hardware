# FPGA Build and Simulation Makefile

#==========================================
# Environment Setup
#==========================================
# OSS CAD Suite path
OSS_CAD_SUITE = /Users/hambook/oss-cad-suite
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
# Source files
#==========================================
RTL_SOURCES = $(SRC_DIR)/kitt.vhdl
TB_SOURCES = $(SIM_DIR)/test.vhdl
TOP_ENTITY = kitt
TB_ENTITY = kitt_tb

# Constraint files (create if needed)
LPF_FILE = $(CONSTRAINTS_DIR)/versa_ecp5.lpf

#==========================================
# FPGA Configuration
#==========================================
# Lattice ECP5-5G Versa board defaults (LFE5UM5G-45F-VERSA-EVN)
FPGA_DEVICE = um5g-45k
FPGA_PACKAGE = CABGA381
FPGA_SPEED = 8

#==========================================
# Build outputs
#==========================================
JSON_FILE = $(BUILD_DIR)/$(TOP_ENTITY).json
TEXTCFG_FILE = $(BUILD_DIR)/$(TOP_ENTITY).config
BITSTREAM_FILE = $(BUILD_DIR)/$(TOP_ENTITY).bit

# Report files
SYNTH_REPORT = $(REPORTS_DIR)/synthesis.txt
PNR_REPORT = $(REPORTS_DIR)/pnr.txt
TIMING_REPORT = $(REPORTS_DIR)/timing.txt
UTILIZATION_REPORT = $(REPORTS_DIR)/utilization.txt

#==========================================
# Simulation parameters
#==========================================
SIM_STOP_TIME = 1ms
SIM_OUTPUT = $(SIM_DIR)/output.txt
VCD_FILE = $(SIM_DIR)/$(TB_ENTITY).vcd
GTKW_FILE = $(SIM_DIR)/$(TB_ENTITY).gtkw
GHDL_FLAGS = --std=08

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
	$(GHDL) -a $(GHDL_FLAGS) --workdir=$(WORK_DIR) $(TB_SOURCES)

# Elaborate (build) testbench
.PHONY: elaborate
elaborate: analyze-tb
	@echo "Elaborating $(TB_ENTITY)..."
	$(GHDL) -e $(GHDL_FLAGS) --workdir=$(WORK_DIR) $(TB_ENTITY)

# Run simulation, generate VCD, and open GTKWave
.PHONY: sim
sim: elaborate
	@echo "Running simulation with VCD output..."
	$(GHDL) -r $(GHDL_FLAGS) --workdir=$(WORK_DIR) $(TB_ENTITY) --stop-time=$(SIM_STOP_TIME) --vcd=$(VCD_FILE)
	@echo "VCD file saved to $(VCD_FILE)"
	@echo "Opening waveform in GTKWave..."
	@if [ -f "$(GTKW_FILE)" ]; then \
		nohup $(GTKWAVE) $(GTKW_FILE) > /dev/null 2>&1 & \
	else \
		nohup $(GTKWAVE) $(VCD_FILE) > /dev/null 2>&1 & \
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
	@echo "  Synthesis:    $(SYNTH_REPORT)"
	@echo "  PnR:          $(PNR_REPORT)"
	@echo "  Timing:       $(TIMING_REPORT)"
	@echo "  Utilization:  $(UTILIZATION_REPORT)"

# Check toolchain
.PHONY: check-tools
check-tools:
	@./install_scripts/check_toolchain.sh

# Clean generated files
.PHONY: clean
clean:
	@echo "Cleaning simulation files..."
	@$(GHDL) --clean $(GHDL_FLAGS) --workdir=$(WORK_DIR) 2>/dev/null || true
	@rm -rf $(WORK_DIR)
	@rm -f $(TB_ENTITY)
	@rm -f *.cf
	@rm -f $(VCD_FILE)

# Clean everything including FPGA build
.PHONY: clean-all distclean
clean-all distclean: clean
	@echo "Cleaning all build files..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(REPORTS_DIR)

# Help target
.PHONY: help
help:
	@echo "FPGA Build and Simulation Makefile"
	@echo ""
	@echo "=== Primary Workflow ==="
	@echo "  make sim        - Run simulation and open GTKWave (default)"
	@echo "  make bitstream  - Build FPGA bitstream with reports"
	@echo "  make program    - Flash to FPGA SRAM (volatile, fast)"
	@echo "  make flash      - Flash to FPGA flash (persistent)"
	@echo ""
	@echo "=== Utility Targets ==="
	@echo "  make reports    - View synthesis/timing/utilization reports"
	@echo "  make clean      - Remove simulation files"
	@echo "  make clean-all  - Remove all build files and reports"
	@echo "  make help       - Show this help"
	@echo ""
	@echo "=== Advanced Options ==="
	@echo "  SIM_STOP_TIME   - Simulation duration (default: $(SIM_STOP_TIME))"
	@echo "  Example: make sim SIM_STOP_TIME=2ms"
	@echo ""
	@echo "=== Typical Workflow ==="
	@echo "  1. make sim         # Verify design in simulation"
	@echo "  2. make bitstream   # Synthesize for FPGA"
	@echo "  3. make reports     # Check timing/utilization"
	@echo "  4. make program     # Flash to SRAM (test)"
	@echo "  5. make flash       # Flash to persistent memory (deploy)"
