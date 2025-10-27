# SIM8-01 System - Top-Level Makefile
# Intel 8008 Support Logic and Glue Logic Implementation
#
# This implements the SIM8-01 reference design from the Intel 8008 User Manual.
# All modules are support circuitry for interfacing with a REAL Intel 8008 chip.

#==========================================
# Project Configuration
#==========================================
# Top-level entity for the complete SIM8-01 system
TOP_ENTITY = sim8_01_top

# Default testbench (when no TEST= is specified)
TB_ENTITY = sim8_01_top_tb

#==========================================
# Source Files
#==========================================
# List all RTL source files here (order matters for dependencies)
# phase_clocks must come before sim8_01_top since it's instantiated there
RTL_SOURCES = $(SRC_DIR)/phase_clocks.vhdl \
              $(SRC_DIR)/sim8_01_top.vhdl
# Add glue logic modules as you create them (before sim8_01_top):
#              $(SRC_DIR)/state_decoder.vhdl \
#              $(SRC_DIR)/timing_generator.vhdl \
#              $(SRC_DIR)/address_latch.vhdl \
#              $(SRC_DIR)/data_bus_buffer.vhdl \
#              $(SRC_DIR)/memory_controller.vhdl \
#              $(SRC_DIR)/io_controller.vhdl \
#              $(SRC_DIR)/interrupt_logic.vhdl \
#              $(SRC_DIR)/ready_generator.vhdl

# List all testbench files here (for make list-tests)
ALL_TB_SOURCES = $(SIM_DIR)/phase_clocks_tb.vhdl \
                 $(SIM_DIR)/sim8_01_top_tb.vhdl
# Add testbenches as you create modules:
#                 $(SIM_DIR)/state_decoder_tb.vhdl \
#                 $(SIM_DIR)/address_latch_tb.vhdl \
#                 $(SIM_DIR)/memory_controller_tb.vhdl

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
# Include Common Build Rules
#==========================================
include common.mk
