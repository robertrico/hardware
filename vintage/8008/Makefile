# Makefile for s8008 (Silicon-Accurate 8008) Component Test
# Tests the cycle-accurate Intel 8008 implementation

#==========================================
# Project Configuration
#==========================================
TOP_ENTITY ?= s8008
TB_ENTITY ?= s8008_tb

#==========================================
# Source Files
#==========================================
RTL_SOURCES = $(SRC_DIR)/components/i8008_alu.vhdl \
              $(SRC_DIR)/components/s8008.vhdl
TB_SOURCES = $(SIM_DIR)/s8008_tb.vhdl

#==========================================
# Include Common Build Rules
#==========================================
include common.mk
