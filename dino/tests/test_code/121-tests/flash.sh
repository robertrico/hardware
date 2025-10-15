#!/bin/bash

# Standalone flash script for Arduino Mega 2560
# Can be used without sourcing env.sh

# Configuration
PROJECT_NAME="mega2560_blink"
BUILD_DIR="build"
MCU="atmega2560"
PROGRAMMER="wiring"
BAUD_RATE="115200"

# Default port (can be overridden with environment variable or command line argument)
UPLOAD_PORT=${UPLOAD_PORT:-${1:-/dev/cu.usbmodem*}}

# Find the actual port if wildcard is used
ACTUAL_PORT=$(ls ${UPLOAD_PORT} 2>/dev/null | head -n 1)

if [ -z "$ACTUAL_PORT" ]; then
    echo "Error: No device found matching ${UPLOAD_PORT}"
    echo ""
    echo "Available ports:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ls /dev/cu.* 2>/dev/null || echo "  No USB devices found"
    else
        ls /dev/ttyACM* /dev/ttyUSB* 2>/dev/null || echo "  No USB devices found"
    fi
    echo ""
    echo "Usage: $0 [port]"
    echo "Example: $0 /dev/cu.usbmodem14201"
    exit 1
fi

# Check if hex file exists
HEX_FILE="${BUILD_DIR}/${PROJECT_NAME}.hex"
if [ ! -f "$HEX_FILE" ]; then
    echo "Error: Hex file not found: $HEX_FILE"
    echo "Please build the project first using 'source env.sh && build'"
    exit 1
fi

echo "================================================"
echo "Flashing Arduino Mega 2560"
echo "================================================"
echo "Port:       ${ACTUAL_PORT}"
echo "MCU:        ${MCU}"
echo "Programmer: ${PROGRAMMER}"
echo "Baud Rate:  ${BAUD_RATE}"
echo "Hex File:   ${HEX_FILE}"
echo "================================================"
echo ""

# Flash the board
avrdude -p ${MCU} \
        -c ${PROGRAMMER} \
        -P ${ACTUAL_PORT} \
        -b ${BAUD_RATE} \
        -D \
        -U flash:w:${HEX_FILE}:i

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================"
    echo "Flash successful!"
    echo "================================================"
else
    echo ""
    echo "================================================"
    echo "Flash failed!"
    echo "================================================"
    exit 1
fi
