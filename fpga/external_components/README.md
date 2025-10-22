# external_components - ECP5-5G Versa Development Kit

FPGA project for the Lattice ECP5-5G Versa Development Kit (LFE5UM5G-45F-VERSA-EVN).

## Hardware

**Board:** Lattice ECP5-5G Versa Development Kit
**Device:** LFE5UM5G-45F-8BG381C
**Package:** 381-ball caBGA
**FPGA:** ECP5-5G (45k LUTs, SERDES capable)

## Prerequisites

### Toolchain
This project uses the open-source FPGA toolchain:

- **GHDL** - VHDL simulator and synthesis
- **Yosys** - Synthesis
- **nextpnr-ecp5** - Place and route
- **ecppack** - Bitstream generation
- **openFPGALoader** - Programming tool

Install via [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build):
```bash
# macOS
brew install --cask oss-cad-suite

# Or download from: https://github.com/YosysHQ/oss-cad-suite-build/releases
```

Verify installation:
```bash
make check-tools
```

## Project Structure

```
external_components/
├── Makefile              # Build system
├── README.md             # This file
├── constraints/
│   └── versa_ecp5.lpf    # Pin constraints for ECP5 Versa board
├── src/
│   └── external_components.vhdl # RTL source code
├── sim/
│   └── test.vhdl         # Testbench
├── build/                # Generated build artifacts
├── work/                 # GHDL work directory
└── reports/              # Synthesis/timing reports
```

## Quick Start

### 1. Verify Toolchain
```bash
make check-tools
```

### 2. Simulate
Run the GHDL testbench to verify functionality:
```bash
make sim                  # Run simulation and open GTKWave
```

### 3. Synthesize
Build the FPGA bitstream:
```bash
make bitstream            # Full build: synth + pnr + bitstream
make reports              # View synthesis/timing reports
```

### 4. Program the FPGA

**Connect the board:**
- Connect 12V power adapter
- Connect USB cable (for programming)
- Set configuration DIP switches (SW4) to Master SPI mode: `010` (SW4.3=Down, SW4.2=Up, SW4.1=Down)

**Program SRAM (volatile - for testing):**
```bash
make program              # Fast, lost on power cycle
```

**Program Flash (persistent):**
```bash
make flash                # Survives power cycles
```

## Makefile Targets

### Simulation
```bash
make analyze-rtl         # Analyze RTL sources only
make analyze-tb          # Analyze RTL + testbench
make elaborate           # Build testbench executable
make sim                 # Run simulation and open GTKWave
```

### FPGA Build
```bash
make bitstream           # Complete build
make program             # Program SRAM (volatile)
make flash               # Program flash (persistent)
make reports             # View synthesis/timing reports
```

### Utilities
```bash
make check-tools         # Verify toolchain installation
make clean               # Clean simulation files
make clean-all           # Clean everything
make help                # Show all targets
```

## Development

Edit the RTL source file [src/external_components.vhdl](src/external_components.vhdl) to implement your design.

Edit the testbench [sim/test.vhdl](sim/test.vhdl) to add test cases.

Edit the constraints [constraints/versa_ecp5.lpf](constraints/versa_ecp5.lpf) if you need different pins.

## Board Configuration

### DIP Switch SW4 (Configuration Mode)
For normal operation, set to **Master SPI** mode:
- SW4.3: **Down** (CFG2 = 0)
- SW4.2: **Up** (CFG1 = 1)
- SW4.3: **Down** (CFG0 = 0)

## Hardware Resources

- [ECP5-5G Versa Board User Guide](https://www.latticesemi.com/products/developmentboardsandkits/ecp55gversadevkit)
- [ECP5-5G Family Datasheet](https://www.latticesemi.com/products/fpgaprogrammabledevices/ecp5)

## References

- GHDL: https://github.com/ghdl/ghdl
- Yosys: https://github.com/YosysHQ/yosys
- nextpnr: https://github.com/YosysHQ/nextpnr
- openFPGALoader: https://github.com/trabucayre/openFPGALoader
- OSS CAD Suite: https://github.com/YosysHQ/oss-cad-suite-build
