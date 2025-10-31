#!/usr/bin/env python3
"""
Convert Intel HEX format to simple memory format for VHDL
Outputs one hex byte per line (without 0x prefix)
"""

def parse_intel_hex(hex_file):
    """Parse Intel HEX format and return dictionary of address:data"""
    memory = {}
    max_addr = 0

    with open(hex_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line.startswith(':'):
                continue

            # Parse Intel HEX record
            byte_count = int(line[1:3], 16)
            address = int(line[3:7], 16)
            record_type = int(line[7:9], 16)

            if record_type == 0x00:  # Data record
                data_start = 9
                for i in range(byte_count):
                    byte_val = int(line[data_start + i*2:data_start + i*2 + 2], 16)
                    memory[address + i] = byte_val
                    max_addr = max(max_addr, address + i)
            elif record_type == 0x01:  # End of file
                break

    return memory, max_addr

if __name__ == "__main__":
    import sys

    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.hex> <output.mem>")
        sys.exit(1)

    hex_file = sys.argv[1]
    mem_file = sys.argv[2]

    memory, max_addr = parse_intel_hex(hex_file)

    # Write memory file - one hex byte per line
    with open(mem_file, 'w') as f:
        for addr in range(max_addr + 1):
            if addr in memory:
                f.write(f"{memory[addr]:02X}\n")
            else:
                f.write("00\n")  # Fill gaps with 0x00

    print(f"Converted {hex_file} -> {mem_file}")
    print(f"  Loaded {len(memory)} bytes")
    print(f"  Address range: 0x{0:04X} - 0x{max_addr:04X}")
