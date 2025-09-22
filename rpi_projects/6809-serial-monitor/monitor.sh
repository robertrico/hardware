#!/bin/bash

# 6809 Serial Monitor Launch Script
# This script connects to the Pico's serial output using screen

# Check if serial port is provided
if [ -z "$1" ]; then
    echo "Usage: ./monitor.sh <serial_port>"
    echo "Example: ./monitor.sh /dev/tty.usbmodem14201"
    echo ""
    echo "To find your serial port, run: ls /dev/tty.*"
    exit 1
fi

SERIAL_PORT=$1
BAUD_RATE=115200

echo "Connecting to 6809 Bus Monitor on $SERIAL_PORT at $BAUD_RATE baud..."
echo "Press Ctrl-A then K to exit screen"
echo ""

# Launch screen with the serial connection
screen $SERIAL_PORT $BAUD_RATE