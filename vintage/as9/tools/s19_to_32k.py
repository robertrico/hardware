#!/usr/bin/env python3
"""
Convert S19 file to 32KB ROM image for 28C256 with A14 tied HIGH.

This script parses an S-record (S19) file and creates a 32KB binary image
suitable for programming a 28C256 EEPROM with pin 1 (A14) tied to +5V.

The code is mapped from CPU addresses $C000-$FFFF to ROM addresses $4000-$7FFF.

Usage:
    python3 s19_to_32k.py input.s19 output.bin
"""

import sys

def parse_s19_to_32k(s19_path, output_path, fill_byte=0xFF, verbose=False):
    """
    Parse S19 file and create 32KB ROM image.

    Args:
        s19_path: Path to input S19 file
        output_path: Path to output 32KB binary file
        fill_byte: Byte value to fill unused ROM space (default 0xFF)
        verbose: Print detailed information
    """
    # Create 32KB blank ROM
    rom_32k = bytearray([fill_byte] * 32768)

    min_addr = 0xFFFF
    max_addr = 0x0000
    bytes_written = 0

    with open(s19_path, 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()

            # Process S1 records (16-bit address)
            if line.startswith('S1'):
                try:
                    # Parse S1 record: S1 LL AAAA DD...DD CC
                    length = int(line[2:4], 16)
                    addr = int(line[4:8], 16)
                    data_len = length - 3  # Subtract address (2) and checksum (1)

                    # Extract data bytes
                    data_hex = line[8:8 + data_len * 2]
                    data = bytes.fromhex(data_hex)

                    # Map CPU address to ROM address
                    # With A14 tied HIGH: CPU $C000-$FFFF maps to ROM $4000-$7FFF
                    if addr >= 0xC000:
                        rom_offset = addr - 0xC000 + 0x4000
                        rom_32k[rom_offset:rom_offset + len(data)] = data

                        min_addr = min(min_addr, addr)
                        max_addr = max(max_addr, addr + len(data) - 1)
                        bytes_written += len(data)

                        if verbose:
                            print(f"  CPU ${addr:04X} → ROM ${rom_offset:04X} ({len(data)} bytes)")
                    elif verbose and addr < 0xC000:
                        print(f"  Skipping CPU ${addr:04X} (below $C000)")

                except (ValueError, IndexError) as e:
                    print(f"Warning: Error parsing line {line_num}: {e}", file=sys.stderr)
                    continue

    # Verify reset vector
    reset_rom_offset = 0xFFFE - 0xC000 + 0x4000
    reset_msb = rom_32k[reset_rom_offset]
    reset_lsb = rom_32k[reset_rom_offset + 1]
    reset_vector = (reset_msb << 8) | reset_lsb

    # Write output file
    with open(output_path, 'wb') as f:
        f.write(rom_32k)

    # Print summary
    print(f"✓ S19 to 32KB ROM conversion complete")
    print(f"  Input:  {s19_path}")
    print(f"  Output: {output_path}")
    print(f"  Size:   {len(rom_32k)} bytes (32KB)")
    print(f"")
    print(f"Address Range:")
    print(f"  CPU addresses:  ${min_addr:04X} - ${max_addr:04X}")
    print(f"  ROM mapping:    $4000 - $7FFF (upper 16KB)")
    print(f"  Bytes written:  {bytes_written}")
    print(f"")
    print(f"Reset Vector:")
    print(f"  CPU address:    $FFFE")
    print(f"  ROM offset:     ${reset_rom_offset:04X}")
    print(f"  Points to:      ${reset_vector:04X}", end="")

    if reset_vector == fill_byte * 0x101:
        print(" ⚠️  (unprogrammed/blank)")
        return False
    else:
        print(" ✓")

    # Show vector table
    print(f"")
    print(f"Vector Table (ROM $7FF0-$7FFF):")
    vectors = [
        (0xFFF0, "Reserved"),
        (0xFFF2, "SWI3"),
        (0xFFF4, "SWI2"),
        (0xFFF6, "FIRQ"),
        (0xFFF8, "IRQ"),
        (0xFFFA, "SWI"),
        (0xFFFC, "NMI"),
        (0xFFFE, "RESET"),
    ]

    for cpu_addr, name in vectors:
        rom_off = cpu_addr - 0xC000 + 0x4000
        msb = rom_32k[rom_off]
        lsb = rom_32k[rom_off + 1]
        vec = (msb << 8) | lsb
        print(f"  ${cpu_addr:04X}: ${vec:04X}  {name}")

    return True

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 s19_to_32k.py input.s19 output.bin [--verbose]")
        print("")
        print("Converts S19 file to 32KB ROM image for 28C256 with A14 tied HIGH")
        print("Maps CPU addresses $C000-$FFFF to ROM addresses $4000-$7FFF")
        sys.exit(1)

    s19_path = sys.argv[1]
    output_path = sys.argv[2]
    verbose = '--verbose' in sys.argv or '-v' in sys.argv

    try:
        success = parse_s19_to_32k(s19_path, output_path, verbose=verbose)
        if not success:
            print("")
            print("⚠️  Warning: Reset vector appears blank. Check your S19 file.")
            sys.exit(1)
    except FileNotFoundError:
        print(f"Error: File not found: {s19_path}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
