#!/bin/bash

# Build script for Arduino test modules
# Usage: ./build-test.sh <test_type>
# Examples:
#   ./build-test.sh 373
#   ./build-test.sh pulse_a
#   ./build-test.sh pulse_b
#   ./build-test.sh register
#   ./build-test.sh ir
#   ./build-test.sh 245_373

if [ $# -eq 0 ]; then
    echo "Usage: $0 <test_type> [frequency_hz]"
    echo "Available tests:"
    echo "  373       - 74LS373 latch test"
    echo "  245_373   - 74LS245 + 74LS373 combined test"
    echo "  ir        - Instruction Register test"
    echo "  register  - Full register module test"
    echo "  pulse_a   - 74LS121 pulse test for Register A"
    echo "  pulse_b   - 74LS121 pulse test for Register B"
    echo "  clock     - Clock generator (requires frequency in Hz)"
    echo ""
    echo "Examples:"
    echo "  $0 373"
    echo "  $0 clock 1000000   # 1MHz clock"
    echo "  $0 clock 80000     # 80kHz clock"
    exit 1
fi

TEST=$1

# Parse test type
case $TEST in
    pulse_a)
        TEST_TYPE="pulse"
        PULSE_REG="a"
        echo "Building 74LS121 pulse test for Register A..."
        ;;
    pulse_b)
        TEST_TYPE="pulse"
        PULSE_REG="b"
        echo "Building 74LS121 pulse test for Register B..."
        ;;
    clock)
        TEST_TYPE="clock"
        if [ $# -lt 2 ]; then
            echo "Error: clock test requires frequency parameter"
            echo "Usage: $0 clock <frequency_hz>"
            echo "Example: $0 clock 1000000  # 1MHz"
            exit 1
        fi
        CLOCK_FREQ=$2
        echo "Building clock generator at ${CLOCK_FREQ}Hz..."
        ;;
    373|245_373|ir|register)
        TEST_TYPE=$TEST
        echo "Building $TEST_TYPE test..."
        ;;
    *)
        echo "Unknown test type: $TEST"
        echo "Run $0 without arguments to see available tests"
        exit 1
        ;;
esac

# Configure with CMake
if [ "$TEST_TYPE" = "pulse" ]; then
    cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=toolchain-avr.cmake -DTEST_TYPE=$TEST_TYPE -DPULSE_REG=$PULSE_REG
elif [ "$TEST_TYPE" = "clock" ]; then
    cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=toolchain-avr.cmake -DTEST_TYPE=$TEST_TYPE -DCLOCK_FREQ=$CLOCK_FREQ
else
    cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=toolchain-avr.cmake -DTEST_TYPE=$TEST_TYPE
fi

if [ $? -ne 0 ]; then
    echo "CMake configuration failed"
    exit 1
fi

# Build
make -C build

if [ $? -ne 0 ]; then
    echo "Build failed"
    exit 1
fi

echo ""
echo "Build successful! To flash to Arduino:"
echo "  make -C build flash"
echo ""
echo "Or use this script with --flash:"
echo "  $0 $TEST --flash"

# Check for --flash flag
# For clock test, flash flag would be the third argument
FLASH_ARG="$2"
if [ "$TEST_TYPE" = "clock" ]; then
    FLASH_ARG="$3"
fi

if [ "$FLASH_ARG" = "--flash" ]; then
    echo ""
    echo "Flashing to Arduino..."
    make -C build flash
fi