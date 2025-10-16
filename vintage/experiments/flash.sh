#!/bin/bash

# Simplified flash script for Arduino Mega 2560 - Multi-test version
# Leverages cmake flash targets
#
# Usage:
#   ./flash.sh [test_name]
#   ./flash.sh              # Flash default test (74LS121)
#   ./flash.sh 74LS121      # Flash specific test
#   ./flash.sh 74LS161      # Flash another test

BUILD_DIR="build"
DEFAULT_TEST="74LS121"

# Parse arguments
TEST_NAME=${1:-$DEFAULT_TEST}

# Check if build directory exists
if [ ! -d "$BUILD_DIR" ]; then
    echo "Error: Build directory not found: $BUILD_DIR"
    echo "Please run: cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=avr-gcc-toolchain.cmake"
    exit 1
fi

# Check if hex file exists
HEX_FILE="${BUILD_DIR}/${TEST_NAME}.hex"
if [ ! -f "$HEX_FILE" ]; then
    echo "Error: Hex file not found: $HEX_FILE"
    echo ""
    echo "Available tests:"
    for hex in ${BUILD_DIR}/*.hex; do
        if [ -f "$hex" ]; then
            basename "$hex" .hex | sed 's/^/  /'
        fi
    done
    echo ""
    echo "To build this test:"
    echo "  cmake --build build --target ${TEST_NAME}.elf"
    exit 1
fi

echo "Flashing ${TEST_NAME} to Arduino Mega 2560..."
echo ""

# Use cmake to flash via the flash_<test_name> target
cmake --build ${BUILD_DIR} --target flash_${TEST_NAME}

if [ $? -eq 0 ]; then
    echo ""
    echo "Flash successful! (${TEST_NAME})"
else
    echo ""
    echo "Flash failed!"
    exit 1
fi
