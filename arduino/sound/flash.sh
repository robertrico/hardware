#!/bin/bash

# AVR Arduino Uno Flash Script
# Flashes the compiled HEX file to /dev/tty.usbserial-143410

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PORT="/dev/tty.usbserial-143440"

# Check if build directory exists
if [ ! -d "build" ]; then
    echo -e "${RED}Error: build directory not found. Run ./build.sh first.${NC}"
    exit 1
fi

# Check if HEX file exists
if [ ! -f "build/avr_uno_blink.hex" ]; then
    echo -e "${RED}Error: avr_uno_blink.hex not found. Run ./build.sh first.${NC}"
    exit 1
fi

# Check if port exists
if [ ! -e "$PORT" ]; then
    echo -e "${RED}Error: Port $PORT not found.${NC}"
    echo -e "${YELLOW}Available serial ports:${NC}"
    ls -l /dev/tty.* 2>/dev/null || echo "No serial ports found"
    exit 1
fi

echo -e "${GREEN}Flashing to $PORT...${NC}"

# Flash using avrdude (called via CMake target)
cd build
cmake --build . --target flash

echo -e "${GREEN}Flash complete!${NC}"
