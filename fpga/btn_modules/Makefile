# btn_modules FPGA Project Makefile
# This file defines project-specific configuration and includes common build rules

#==========================================
# Project Configuration
#==========================================
# Top-level entity and testbench names
TOP_ENTITY = btn_modules_top
# Default testbench when TEST is not specified
TB_ENTITY = btn_modules_tb

# RTL Source files (all modules in src/)
RTL_SOURCES = $(SRC_DIR)/debouncer.vhdl \
              $(SRC_DIR)/btn_modules.vhdl \
              $(SRC_DIR)/btn_modules_top.vhdl

# Default testbench (for backward compatibility)
TB_SOURCES = $(SIM_DIR)/btn_modules_tb.vhdl

# All available testbenches (for TEST= parameter)
ALL_TB_SOURCES = $(SIM_DIR)/btn_modules_tb.vhdl \
                 $(SIM_DIR)/debouncer_test.vhdl

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
# Include Common Build Rules
#==========================================
include ../common.mk
