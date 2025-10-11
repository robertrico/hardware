#!/bin/bash

# Flash script for Arduino Due using bossac
# This script is called by CMake's flash target

# Configuration
PORT=${DUE_PORT:-/dev/tty.usbmodem1434201}
BOSSAC=/usr/local/bin/bossac
BINARY=${1:-arduino_due_blink.bin}

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo "Error: Binary file '$BINARY' not found"
    exit 1
fi

echo "Flashing $BINARY to Arduino Due..."
echo "Please press and release the ERASE button on your Arduino Due now..."
echo "Waiting for bootloader..."

# Wait for bootloader port to appear
BOOTLOADER_PORT=""
for i in {1..10}; do
    sleep 0.5
    # Check if original port is in bootloader mode
    if $BOSSAC --port=$(basename $PORT) -i >/dev/null 2>&1; then
        BOOTLOADER_PORT=$(basename $PORT)
        break
    fi
    # Sometimes bootloader appears as a different port
    for port in /dev/tty.usbmodem*; do
        if [ -e "$port" ] && $BOSSAC --port=$(basename $port) -i >/dev/null 2>&1; then
            BOOTLOADER_PORT=$(basename $port)
            break 2
        fi
    done
done

if [ -z "$BOOTLOADER_PORT" ]; then
    echo "Error: Bootloader not found. Make sure you pressed the ERASE button."
    exit 1
fi

echo "Found bootloader on $BOOTLOADER_PORT"

# Flash with bossac
# -e = erase
# -w = write
# -v = verify
# -b = boot from flash
# -R = reset
# -u = unlock regions
$BOSSAC -e -w -v -b -u -R --port=$BOOTLOADER_PORT $BINARY

if [ $? -eq 0 ]; then
    echo "Flash successful!"
else
    echo "Flash failed!"
    exit 1
fi
