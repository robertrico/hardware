#!/bin/bash
# Slow S19 loader for ASSIST09
# Sends data with delays to ensure ASSIST09 can keep up

if [ $# -ne 2 ]; then
    echo "Usage: $0 <serial_port> <s19_file>"
    echo "Example: $0 /dev/tty.usbserial-1234 build/test_acia/main.s19"
    echo ""
    echo "Available serial ports:"
    ls /dev/tty.* 2>/dev/null | grep -i usb || echo "  (none found)"
    exit 1
fi

SERIAL_PORT="$1"
S19_FILE="$2"

if [ ! -e "$SERIAL_PORT" ]; then
    echo "Error: Serial port not found: $SERIAL_PORT"
    exit 1
fi

if [ ! -f "$S19_FILE" ]; then
    echo "Error: S19 file not found: $S19_FILE"
    exit 1
fi

echo "Loading $S19_FILE to $SERIAL_PORT..."
echo "Sending 'L' command to ASSIST09..."

# Send 'L' command followed by carriage return
printf "L\r" > "$SERIAL_PORT"

# Wait 0.5ms (500 microseconds) for ASSIST09 to process the L command
sleep 0.0005

# Send each line character by character with small delays
while IFS= read -r line; do
    echo "Sending: $line"
    for ((i=0; i<${#line}; i++)); do
        char="${line:$i:1}"
        printf "%s" "$char" > "$SERIAL_PORT"
        sleep 0.001  # 1ms between characters (57600 baud)
    done

    # Only send CR after S1 records, not after S9
    # S9 triggers immediate exit, CR would be read as command
    if [[ "$line" != S9* ]]; then
        printf "\r" > "$SERIAL_PORT"
        echo "  (sent CR)"
    else
        echo "  (S9 - no CR sent, ASSIST09 will exit)"
    fi
    sleep 0.01
done < "$S19_FILE"

# Wait a moment for ASSIST09 to process the S9 and return to prompt
sleep 0.1

echo ""
echo "Done! Load complete."
echo "In ASSIST09, type: G 100"
