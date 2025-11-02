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
              $(SRC_DIR)/components/phase_clocks.vhdl \
              $(SRC_DIR)/components/s8008.vhdl

# Main comprehensive testbench
TB_SOURCES = $(SIM_DIR)/s8008_tb.vhdl

# All testbenches (main + units)
ALL_TB_SOURCES = $(TB_SOURCES) \
                 $(wildcard $(SIM_DIR)/units/*_tb.vhdl)

#==========================================
# Test-Specific Stop Times
#==========================================
# Benchmark-derived optimal stop times for each test
# Main comprehensive test completes at 1910us (1.91ms)
# Adding 30% margin for safety
STOP_TIME_s8008_tb = 2500us

# Unit tests (fast, typically <100us)
# Conditional test now has more instructions due to flag setup, needs more time
STOP_TIME_s8008_conditional_tb = 1000us
STOP_TIME_s8008_call_ret_tb = 800us
STOP_TIME_s8008_alu_tb = 1400us
STOP_TIME_s8008_io_tb = 100us
STOP_TIME_s8008_rotate_tb = 400us
STOP_TIME_s8008_stack_tb = 200us

# Get stop time for active test, or use default
SIM_STOP_TIME ?= $(or $(STOP_TIME_$(ACTIVE_TB_ENTITY)),1ms)

#==========================================
# Include Common Build Rules
#==========================================
include common.mk

#==========================================
# Extended Test Targets
#==========================================

# Run main comprehensive test (default)
.PHONY: test
test: sim

# Run all unit tests
.PHONY: test-units
test-units:
	@echo "========================================"
	@echo "Running All Unit Tests"
	@echo "========================================"
	@for tb in $(wildcard $(SIM_DIR)/units/*_tb.vhdl); do \
		test_name=$$(basename $$tb .vhdl); \
		echo ""; \
		echo ">>> Running $$test_name..."; \
		$(MAKE) sim TEST=$$test_name || exit 1; \
	done
	@echo ""
	@echo "========================================"
	@echo "✓ All Unit Tests Passed"
	@echo "========================================"

# Run everything: comprehensive + all units
.PHONY: test-all
test-all: test test-units
	@echo ""
	@echo "========================================"
	@echo "✓ ALL TESTS PASSED"
	@echo "  - Comprehensive test: PASS"
	@echo "  - Unit tests: PASS"
	@echo "========================================"

# Quick shortcuts for specific unit tests
.PHONY: test-conditional test-call-ret test-alu test-io test-rotate test-stack
test-conditional:
	@$(MAKE) sim TEST=s8008_conditional_tb

test-call-ret:
	@$(MAKE) sim TEST=s8008_call_ret_tb

test-alu:
	@$(MAKE) sim TEST=s8008_alu_tb

test-io:
	@$(MAKE) sim TEST=s8008_io_tb

test-rotate:
	@$(MAKE) sim TEST=s8008_rotate_tb

test-stack:
	@$(MAKE) sim TEST=s8008_stack_tb
