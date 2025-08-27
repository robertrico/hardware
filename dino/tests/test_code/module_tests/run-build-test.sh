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
    echo "Usage: $0 <test_type>"
    echo "Available tests:"
    echo "  373       - 74LS373 latch test"
    echo "  245_373   - 74LS245 + 74LS373 combined test"
    echo "  ir        - Instruction Register test"
    echo "  register  - Full register module test"
    echo "  pulse_a   - 74LS121 pulse test for Register A"
    echo "  pulse_b   - 74LS121 pulse test for Register B"
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
    cmake -S . -B build -DTEST_TYPE=$TEST_TYPE -DPULSE_REG=$PULSE_REG
else
    cmake -S . -B build -DTEST_TYPE=$TEST_TYPE
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
if [ "$2" = "--flash" ]; then
    echo ""
    echo "Flashing to Arduino..."
    make -C build flash
fi