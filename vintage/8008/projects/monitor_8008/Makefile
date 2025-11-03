# Makefile for Interactive 8008 Monitor Project
# Real-time interactive terminal via VHPIDIRECT

#==========================================
# Project Configuration
#==========================================
PROJECT_NAME = monitor_8008
TOP_ENTITY ?= s8008
TB_ENTITY ?= s8008_monitor_tb

# Project root directory
PROJECT_ROOT = ../..
WORK_DIR = work

#==========================================
# Override default target BEFORE including common.mk
#==========================================
.DEFAULT_GOAL := sim-interactive

#==========================================
# Simulation Configuration
#==========================================
# Run for a long time (interactive mode)
STOP_TIME_s8008_monitor_tb = 3600sec
SIM_STOP_TIME ?= $(or $(STOP_TIME_$(TB_ENTITY)),3600sec)

#==========================================
# Include Common Build Rules
#==========================================
include $(PROJECT_ROOT)/common.mk

#==========================================
# Override GHDL to use Homebrew version for VHPIDIRECT support
#==========================================
GHDL = /opt/homebrew/bin/ghdl

#==========================================
# Source Files
#==========================================
RTL_SOURCES = $(PROJECT_ROOT)/src/components/i8008_alu.vhdl \
              $(PROJECT_ROOT)/src/components/phase_clocks.vhdl \
              $(PROJECT_ROOT)/src/components/rom_2kx8.vhdl \
              $(PROJECT_ROOT)/src/components/ram_1kx8.vhdl \
              $(PROJECT_ROOT)/src/components/s8008.vhdl \
              io_console_interactive.vhdl

TB_SOURCES = s8008_monitor_tb.vhdl

# C source for VHPIDIRECT
C_SOURCES = console_vhpi.c
C_LIB = libconsole_vhpi.so

#==========================================
# Program Assembly Configuration
#==========================================
NAKEN_ASM ?= /Users/hackbook/Development/naken_asm/naken_asm
PYTHON = python3

#==========================================
# VHPIDIRECT Compilation
#==========================================
# Compile C code into shared library for VHPIDIRECT
$(C_LIB): $(C_SOURCES)
	@echo "Compiling $< for VHPIDIRECT..."
	gcc -shared -fPIC -o $@ $<

# Override simulation target to include C library
.PHONY: sim-interactive
sim-interactive: $(WORK_DIR) $(C_LIB) hex2mem
	@echo "=========================================="
	@echo "Starting Interactive 8008 Monitor"
	@echo "=========================================="
	@echo ""
	@echo "Analyzing RTL sources..."
	$(GHDL) -a --std=08 --workdir=$(WORK_DIR) $(RTL_SOURCES)
	@echo "Analyzing testbench..."
	$(GHDL) -a --std=08 --workdir=$(WORK_DIR) $(TB_SOURCES)
	@echo "Elaborating with C library..."
	$(GHDL) -e --std=08 --workdir=$(WORK_DIR) -Wl,$(C_LIB) $(TB_ENTITY)
	@echo ""
	@echo "╔═══════════════════════════════════════════╗"
	@echo "║  Intel 8008 Interactive Monitor           ║"
	@echo "║  Type '?' for help                        ║"
	@echo "║  Press Ctrl+C to stop simulation          ║"
	@echo "╚═══════════════════════════════════════════╝"
	@echo ""
	@# Run the simulation (redirect stderr to /dev/null to suppress debug output)
	@$(GHDL) -r --std=08 --workdir=$(WORK_DIR) $(TB_ENTITY) --stop-time=$(SIM_STOP_TIME) --assert-level=error 2>/dev/null || true

#==========================================
# Project-Specific Targets
#==========================================

# Assemble the monitor program
.PHONY: asm
asm:
	@echo "=== Assembling monitor.asm ==="
	$(NAKEN_ASM) -I . -l -type hex -o monitor.hex monitor.asm
	@echo "✓ Assembly complete"

# Convert to MEM format
.PHONY: hex2mem
hex2mem: asm
	@echo "=== Converting to MEM format ==="
	$(PYTHON) $(PROJECT_ROOT)/hex_to_mem.py monitor.hex monitor.mem
	@echo "✓ Generated monitor.mem"

# Main target - build and run interactive monitor
.PHONY: all
all: sim-interactive

# Clean project files
.PHONY: clean-proj
clean-proj: clean
	rm -f monitor.hex monitor.lst monitor.mem
	rm -f $(C_LIB)
	rm -f console_output.txt

.PHONY: help-proj
help-proj:
	@echo "8008 Interactive Monitor - Makefile"
	@echo "===================================="
	@echo ""
	@echo "Targets:"
	@echo "  all             - Build and run interactive monitor (default)"
	@echo "  sim-interactive - Run interactive simulation with VHPIDIRECT"
	@echo "  asm             - Assemble monitor.asm"
	@echo "  hex2mem         - Convert hex to mem format"
	@echo "  clean-proj      - Clean generated files"
	@echo ""
	@echo "This monitor provides REAL interactive I/O:"
	@echo "  - Type commands and the 8008 responds"
	@echo "  - INP instructions actually wait for your keypress"
	@echo "  - OUT instructions immediately write to your terminal"
