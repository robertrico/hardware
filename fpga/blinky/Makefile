# FPGA Build and Simulation Makefile

#==========================================
# Environment Setup
#==========================================
# OSS CAD Suite path
OSS_CAD_SUITE = /Users/hackbook/oss-cad-suite
SHELL := /bin/bash
export PATH := $(OSS_CAD_SUITE)/bin:$(PATH)

#==========================================
# Tools
#==========================================
GHDL = ghdl
YOSYS = yosys
NEXTPNR = nextpnr-ecp5
ECPPACK = ecppack
OPENFPGALOADER = openFPGALoader

#==========================================
# Directories
#==========================================
SRC_DIR = src
SIM_DIR = sim
BUILD_DIR = build
WORK_DIR = work
CONSTRAINTS_DIR = constraints

#==========================================
# Source files
#==========================================
RTL_SOURCES = $(SRC_DIR)/blink.vhdl
TB_SOURCES = $(SIM_DIR)/test.vhdl
TOP_ENTITY = blinky
TB_ENTITY = blinky_tb

# Constraint files (create if needed)
LPF_FILE = $(CONSTRAINTS_DIR)/versa_ecp5.lpf

#==========================================
# FPGA Configuration
#==========================================
# Lattice ECP5-5G Versa board defaults (LFE5UM5G-45F-VERSA-EVN)
FPGA_DEVICE = 45k
FPGA_PACKAGE = CABGA381
FPGA_SPEED = 8

#==========================================
# Build outputs
#==========================================
JSON_FILE = $(BUILD_DIR)/$(TOP_ENTITY).json
TEXTCFG_FILE = $(BUILD_DIR)/$(TOP_ENTITY).config
BITSTREAM_FILE = $(BUILD_DIR)/$(TOP_ENTITY).bit

#==========================================
# Simulation parameters
#==========================================
SIM_STOP_TIME = 1ms
SIM_OUTPUT = $(SIM_DIR)/output.txt
GHDL_FLAGS = --std=08

#==========================================
# Default Targets
#==========================================
.PHONY: all
all: elaborate

.PHONY: fpga
fpga: bitstream

#==========================================
# Directory Creation
#==========================================
$(WORK_DIR):
	@mkdir -p $(WORK_DIR)

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

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

# Run simulation interactively (output to terminal)
.PHONY: run
run: elaborate
	@echo "Running simulation..."
	$(GHDL) -r $(GHDL_FLAGS) --workdir=$(WORK_DIR) $(TB_ENTITY) --stop-time=$(SIM_STOP_TIME)

# Run simulation and save output to file
.PHONY: simulate
simulate: elaborate
	@echo "Running simulation (saving to $(SIM_OUTPUT))..."
	$(GHDL) -r $(GHDL_FLAGS) --workdir=$(WORK_DIR) $(TB_ENTITY) --stop-time=$(SIM_STOP_TIME) > $(SIM_OUTPUT)
	@echo "Output saved to $(SIM_OUTPUT)"

# View simulation output
.PHONY: view
view:
	@if [ -f $(SIM_OUTPUT) ]; then \
		cat $(SIM_OUTPUT); \
	else \
		echo "No output file found. Run 'make simulate' first."; \
	fi

#==========================================
# FPGA Synthesis Flow
#==========================================

# Synthesis: VHDL -> JSON netlist (using GHDL synth)
$(JSON_FILE): $(RTL_SOURCES) | $(BUILD_DIR)
	@echo "Analyzing VHDL for synthesis..."
	$(GHDL) -a $(GHDL_FLAGS) $(RTL_SOURCES)
	@echo "Synthesizing with GHDL and Yosys..."
	$(GHDL) --synth $(GHDL_FLAGS) --out=verilog $(TOP_ENTITY) > $(BUILD_DIR)/$(TOP_ENTITY).v
	@echo "Running Yosys synthesis..."
	$(YOSYS) -p "read_verilog $(BUILD_DIR)/$(TOP_ENTITY).v; synth_ecp5 -top $(TOP_ENTITY) -json $(JSON_FILE)"

.PHONY: synth synthesis
synth synthesis: $(JSON_FILE)

# Place & Route: JSON -> config file
$(TEXTCFG_FILE): $(JSON_FILE)
	@echo "Running place and route..."
	@if [ -f "$(LPF_FILE)" ]; then \
		$(NEXTPNR) --$(FPGA_DEVICE) --package $(FPGA_PACKAGE) --speed $(FPGA_SPEED) \
			--json $(JSON_FILE) --textcfg $(TEXTCFG_FILE) --lpf $(LPF_FILE) --lpf-allow-unconstrained; \
	else \
		echo "Warning: No constraints file found at $(LPF_FILE)"; \
		echo "Running without pin constraints..."; \
		$(NEXTPNR) --$(FPGA_DEVICE) --package $(FPGA_PACKAGE) --speed $(FPGA_SPEED) \
			--json $(JSON_FILE) --textcfg $(TEXTCFG_FILE); \
	fi

.PHONY: pnr
pnr: $(TEXTCFG_FILE)

# Pack: config -> bitstream
$(BITSTREAM_FILE): $(TEXTCFG_FILE)
	@echo "Generating bitstream..."
	$(ECPPACK) $(TEXTCFG_FILE) $(BITSTREAM_FILE)

.PHONY: bitstream
bitstream: $(BITSTREAM_FILE)

# Program FPGA
.PHONY: program flash
program flash: $(BITSTREAM_FILE)
	@echo "Programming FPGA..."
	$(OPENFPGALOADER) -b versa_ecp5 $(BITSTREAM_FILE)

# Program to SRAM (volatile, faster for testing)
.PHONY: program-sram
program-sram: $(BITSTREAM_FILE)
	@echo "Programming FPGA SRAM..."
	$(OPENFPGALOADER) -b versa_ecp5 -m $(BITSTREAM_FILE)

#==========================================
# Utility Targets
#==========================================

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

# Clean everything including FPGA build
.PHONY: clean-all distclean
clean-all distclean: clean
	@echo "Cleaning all build files..."
	@rm -rf $(BUILD_DIR)

# Help target
.PHONY: help
help:
	@echo "FPGA Build and Simulation Makefile"
	@echo ""
	@echo "=== Simulation Targets ==="
	@echo "  all (default)  - Analyze and elaborate testbench"
	@echo "  analyze-rtl    - Analyze RTL sources only"
	@echo "  analyze-tb     - Analyze RTL and testbench sources"
	@echo "  elaborate      - Analyze and elaborate (build testbench)"
	@echo "  run            - Run simulation (output to terminal)"
	@echo "  simulate       - Run simulation (save to $(SIM_OUTPUT))"
	@echo "  view           - View saved simulation output"
	@echo ""
	@echo "=== FPGA Build Targets ==="
	@echo "  fpga           - Full FPGA build (synth + pnr + bitstream)"
	@echo "  synth          - Synthesize VHDL to netlist"
	@echo "  pnr            - Place and route"
	@echo "  bitstream      - Generate bitstream file"
	@echo "  program        - Program FPGA flash (persistent)"
	@echo "  program-sram   - Program FPGA SRAM (volatile, fast)"
	@echo ""
	@echo "=== Utility Targets ==="
	@echo "  check-tools    - Verify toolchain installation"
	@echo "  clean          - Remove simulation files"
	@echo "  clean-all      - Remove all generated files"
	@echo "  help           - Show this help"
	@echo ""
	@echo "=== Variables ==="
	@echo "  SIM_STOP_TIME  - Simulation duration (default: $(SIM_STOP_TIME))"
	@echo "  FPGA_DEVICE    - FPGA size (default: $(FPGA_DEVICE))"
	@echo ""
	@echo "=== Examples ==="
	@echo "  make run                    # Simulate"
	@echo "  make fpga                   # Build bitstream"
	@echo "  make program-sram           # Quick FPGA test"
	@echo "  make run SIM_STOP_TIME=2ms  # Longer simulation"
