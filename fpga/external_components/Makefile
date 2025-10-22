# External Components FPGA Project Makefile
# This file defines project-specific configuration and includes common build rules

#==========================================
# Project Configuration
#==========================================
# Top-level entity and testbench names
TOP_ENTITY = external_components
TB_ENTITY = external_components_tb

# Source files
RTL_SOURCES = $(SRC_DIR)/external_components.vhdl
TB_SOURCES = $(SIM_DIR)/test.vhdl

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
