# Attribution and Licensing Information

## Project Overview

This is a **VHDL implementation** of the Intel SIM8-01 reference design, created by **Robert Rico in 2025**.

The VHDL code is based on and derived from multiple sources, adapted for FPGA implementation:
- Intel 8008 architecture documentation and datasheets
- Intel SIM8-01 reference design schematics
- Michael Kohn's i8008 Verilog implementation (converted/adapted to VHDL)
- Vintage IC datasheets for support components

## Copyright

**Copyright (c) 2025 Robert Rico**

VHDL conversion and SIM8-01 system integration work.

## License

This project is licensed under the **MIT License**. See [LICENSE.txt](LICENSE.txt) for full license text.

## Primary Source: Michael Kohn's i8008 Verilog

The i8008 CPU core and ALU in this project are **derived from** Michael Kohn's i8008 Verilog implementation:

- **Author**: Michael Kohn
- **Original Language**: Verilog
- **Website**: https://www.mikekohn.net/
- **License**: MIT
- **Copyright**: 2022-2024 Michael Kohn

The VHDL versions (`i8008_cpu.vhdl`, `i8008_alu.vhdl`) are conversions/adaptations of Kohn's Verilog code, not independent implementations. The architecture, instruction decoding, and ALU operations follow Kohn's original design.

## Original Work by Robert Rico

The following components are original implementations by Robert Rico (2025):

### System Integration
- `sim8_01_top.vhdl` - Silicon interface with address demultiplexing for real 8008 chip
- `sim8_01_top_softcore.vhdl` - Softcore testing environment
- `phase_clocks.vhdl` - Two-phase non-overlapping clock generator

### Support IC Models (from vintage datasheets)
- `ic8267.vhdl` - Signetics 8267 Quad 2-Input Multiplexer
- `ic8263.vhdl` - Signetics 8263 Quad Bus Transceiver
- `ic3205.vhdl` - 74LS138/3205 1-of-8 Decoder
- `ic3404.vhdl` - 74LS373/3404 6-bit Latch

### Memory Components
- `rom_2kx8.vhdl` - 2K x 8 ROM with initialization
- `ram_1kx8.vhdl` - 1K x 8 RAM

### Testbenches
- All simulation testbenches in `sim/`

## Intel Source Materials

The Intel SIM8-01 system design is based on:
- **Intel 8008 Datasheet** (1972, 1978)
- **Intel 8008 User's Manual**
- **Intel SIM8-01 Reference Design Schematic**

These provide the original specifications for the 8008 architecture and reference design.

## Vintage IC Datasheets

Support IC implementations based on original datasheets:
- **Signetics 8267** Quad 2-Input Multiplexer datasheet
- **Signetics 8263** Quad Bus Transceiver datasheet
- **74LS138 / 3205** 1-of-8 Decoder datasheet
- **74LS373 / 3404** Octal Latch datasheet

## What's Original vs. Derived

### Derived from Michael Kohn's Verilog:
✓ i8008 CPU core architecture and state machine
✓ ALU implementation and operations
✓ Instruction decoding logic
✓ Register file organization

**These are VHDL conversions/adaptations, not independent rewrites.**

### Original work by Robert Rico:
✓ VHDL conversion of Verilog code
✓ SIM8-01 system integration and glue logic
✓ Address demultiplexing for real silicon interface
✓ Two-phase clock generation
✓ Support IC functional models from datasheets
✓ Memory components
✓ Complete testing infrastructure

## Trademarks

- Intel, 8008, and SIM8-01 are trademarks of Intel Corporation
- Signetics is a trademark of Philips/NXP
- Other trademarks belong to their respective owners

This is an independent educational project, not an official product.

## Disclaimer

This hardware design is provided "as-is" for educational and historical preservation purposes. When interfacing with vintage hardware:
- Verify voltage levels carefully
- Test with non-critical hardware first
- Use appropriate level shifters and protection
- Proceed at your own risk

## Acknowledgments

- **Michael Kohn** for the original i8008 Verilog implementation that forms the basis of the CPU core
- **Intel Corporation** for the original 8008 microprocessor and SIM8-01 design
- The **vintage computing community** for preservation of documentation
- IC manufacturers for original datasheets and specifications
