# SIM8-01 System - Top-Level Makefile
# Intel 8008 Support Logic and Glue Logic Implementation
#
# This implements the SIM8-01 reference design from the Intel 8008 User Manual.
# All modules are support circuitry for interfacing with a REAL Intel 8008 chip.

#==========================================
# Project Configuration
#==========================================
# Top-level entity - can be overridden on command line:
#   make                    # Tests silicon interface (default)
#   make test-softcore      # Tests softcore version
#   make TOP=sim8_01_top_softcore  # Alternative way
TOP_ENTITY ?= sim8_01_top

# Default testbench - automatically matches TOP_ENTITY
# Can be overridden with TB_ENTITY=name
ifeq ($(TOP_ENTITY),sim8_01_top_softcore)
    TB_ENTITY ?= sim8_01_top_softcore_tb
else ifeq ($(TOP_ENTITY),sim8_01_top)
    TB_ENTITY ?= sim8_01_top_tb
else
    TB_ENTITY ?= $(TOP_ENTITY)_tb
endif

#==========================================
# Source Files
#==========================================
# List all RTL source files here (order matters for dependencies)
# phase_clocks must come before sim8_01_top since it's instantiated there
RTL_SOURCES = $(SRC_DIR)/components/ic8263.vhdl \
              $(SRC_DIR)/components/ic8267.vhdl \
              $(SRC_DIR)/components/ic3205.vhdl \
              $(SRC_DIR)/components/ic3404.vhdl \
              $(SRC_DIR)/components/rom_2kx8.vhdl \
              $(SRC_DIR)/components/ram_1kx8.vhdl \
              $(SRC_DIR)/components/i8008_alu.vhdl \
              $(SRC_DIR)/components/i8008_cpu.vhdl \
              $(SRC_DIR)/phase_clocks.vhdl \
              $(SRC_DIR)/$(TOP_ENTITY).vhdl

# List all testbench files here (for make list-tests)
ALL_TB_SOURCES = $(SIM_DIR)/ic8263_tb.vhdl \
                 $(SIM_DIR)/ic8267_tb.vhdl \
                 $(SIM_DIR)/ic3205_tb.vhdl \
                 $(SIM_DIR)/ic3404_tb.vhdl \
                 $(SIM_DIR)/rom_2kx8_tb.vhdl \
                 $(SIM_DIR)/ram_1kx8_tb.vhdl \
                 $(SIM_DIR)/i8008_cpu_tb.vhdl \
                 $(SIM_DIR)/phase_clocks_tb.vhdl \
                 $(SIM_DIR)/sim8_01_top_tb.vhdl \
                 $(SIM_DIR)/sim8_01_top_softcore_tb.vhdl

# Default testbench sources (when TEST= is not specified)
TB_SOURCES = $(SIM_DIR)/$(TB_ENTITY).vhdl

#==========================================
# Optional Overrides
#==========================================
# Uncomment and modify these if you need non-default values:
# SIM_STOP_TIME = 2ms        # Simulation duration (default: 1ms)
# FPGA_DEVICE = um5g-45k     # FPGA device (default: um5g-45k)
# FPGA_PACKAGE = CABGA381    # Package type (default: CABGA381)
# FPGA_SPEED = 8             # Speed grade (default: 8)
# GHDL_FLAGS = --std=08      # GHDL flags (default: --std=08)

#==========================================
# Program Assembly Configuration
#==========================================
NAKEN_ASM ?= /Users/hackbook/Development/naken_asm/naken_asm
TEST_PROG_DIR = test_programs
PYTHON = python3

# Default program to load
ROM_PROGRAM ?= ram_test

#==========================================
# Convenience Targets
#==========================================
.PHONY: test-silicon test-softcore test-both
.PHONY: asm load-rom asm-and-load list-programs

# Test silicon interface (default)
test-silicon:
	@echo "=== Testing Silicon Interface (real 8008 chip) ==="
	$(MAKE) sim TOP_ENTITY=sim8_01_top TB_ENTITY=sim8_01_top_tb

# Test softcore version
test-softcore:
	@echo "=== Testing Softcore Version (VHDL CPU) ==="
	$(MAKE) sim TOP_ENTITY=sim8_01_top_softcore TB_ENTITY=sim8_01_top_softcore_tb

# Test both versions
test-both: test-silicon test-softcore
	@echo "=== Both tests completed ==="

#==========================================
# Program Assembly and ROM Loading
#==========================================

# List available programs
list-programs:
	@echo "Available programs in $(TEST_PROG_DIR):"
	@cd $(TEST_PROG_DIR) && ls -1 *.asm | sed 's/\.asm//'
	@echo ""
	@echo "Usage:"
	@echo "  make asm ROM_PROGRAM=program_name      # Assemble program"
	@echo "  make load-rom ROM_PROGRAM=program_name # Load into ROM"
	@echo "  make asm-and-load ROM_PROGRAM=program_name  # Assemble and load"
	@echo ""
	@echo "Current ROM program: $(ROM_PROGRAM)"

# Assemble a program
asm:
	@echo "=== Assembling $(ROM_PROGRAM).asm ==="
	@if [ ! -f "$(TEST_PROG_DIR)/$(ROM_PROGRAM).asm" ]; then \
		echo "Error: $(TEST_PROG_DIR)/$(ROM_PROGRAM).asm not found"; \
		echo "Available programs:"; \
		cd $(TEST_PROG_DIR) && ls -1 *.asm; \
		exit 1; \
	fi
	cd $(TEST_PROG_DIR) && $(NAKEN_ASM) -I . -l -type hex -o $(ROM_PROGRAM).hex $(ROM_PROGRAM).asm
	@echo "✓ Assembly complete: $(TEST_PROG_DIR)/$(ROM_PROGRAM).hex"
	@echo "✓ Listing file: $(TEST_PROG_DIR)/$(ROM_PROGRAM).lst"

# Convert HEX to MEM format and update ROM
load-rom:
	@echo "=== Loading $(ROM_PROGRAM) into ROM ==="
	@if [ ! -f "$(TEST_PROG_DIR)/$(ROM_PROGRAM).hex" ]; then \
		echo "Error: $(TEST_PROG_DIR)/$(ROM_PROGRAM).hex not found"; \
		echo "Run 'make asm ROM_PROGRAM=$(ROM_PROGRAM)' first"; \
		exit 1; \
	fi
	$(PYTHON) hex_to_mem.py $(TEST_PROG_DIR)/$(ROM_PROGRAM).hex $(TEST_PROG_DIR)/$(ROM_PROGRAM).mem
	@echo "✓ Generated $(TEST_PROG_DIR)/$(ROM_PROGRAM).mem"
	sed -i '' 's|test_programs/[^"]*\.mem|test_programs/$(ROM_PROGRAM).mem|' src/components/rom_2kx8.vhdl
	@echo "✓ Updated ROM to load $(ROM_PROGRAM).mem"
	@grep "load_rom" src/components/rom_2kx8.vhdl | grep signal

# Assemble and load in one step
asm-and-load: asm load-rom
	@echo "=== Program $(ROM_PROGRAM) assembled and loaded into ROM ==="

#==========================================
# Include Common Build Rules
#==========================================
include common.mk
