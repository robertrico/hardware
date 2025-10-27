# SIM8-01 System - Intel 8008 Support Logic

FPGA implementation of the **SIM8-01** reference system from the original Intel 8008 User Manual. This project implements all the **glue logic and support circuitry** needed to interface with a **real Intel 8008 microprocessor chip**.

## Project Goal

Build the complete SIM8-01 system using FPGA for:
1. **Glue logic** - All support circuitry for the real 8008 chip
2. **Memory interface** - RAM/ROM controllers
3. **I/O interface** - Peripheral interfacing
4. **Clock generation** - Two-phase non-overlapping clocks (φ1/φ2)
5. **Testing** - Validate with softcore 8008 before connecting silicon

## About the Intel 8008

The Intel 8008 was the world's first 8-bit microprocessor, introduced by Intel in April 1972. This project implements the support system to get real 8008 silicon running.

### Specifications
- **Year**: 1972
- **Architecture**: 8-bit microprocessor
- **Clock Speed**: 500 kHz (8008-1) to 800 kHz (8008-2)
- **Instruction Set**: 48 instructions
- **Registers**: 7 general-purpose 8-bit registers (A, B, C, D, E, H, L)
- **Stack**: 8-level internal stack (14-bit addresses)
- **Address Space**: 16 KB (14-bit address bus)
- **Data Bus**: 8-bit bidirectional
- **I/O**: 24 I/O ports (8-bit addressing)

## Hardware Platform

**Target Board:** Lattice ECP5-5G Versa Development Kit
**Device:** LFE5UM5G-45F-8BG381C
**Package:** 381-ball caBGA
**FPGA:** ECP5-5G (45k LUTs, SERDES capable)

## Toolchain

This project uses the open-source FPGA toolchain:

- **GHDL** - VHDL simulator and synthesis
- **Yosys** - Synthesis
- **nextpnr-ecp5** - Place and route
- **ecppack** - Bitstream generation
- **openFPGALoader** - Programming tool
- **GTKWave** - Waveform viewer

### Installation

Install via [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build):

```bash
# macOS
brew install --cask oss-cad-suite

# Or download from: https://github.com/YosysHQ/oss-cad-suite-build/releases
```

### Environment Setup

The build system uses a `.env` file to configure machine-specific settings.

**First-time setup:**
```bash
cp .env.example .env
# Edit .env and set your username
```

**Example `.env` file:**
```bash
# Set to your macOS username (e.g., hambook or hackbook)
USERNAME=hackbook
```

The Makefile will automatically use `/Users/$(USERNAME)/oss-cad-suite` as the tool path.

## Project Structure

### Directory Layout
```
8008/
├── common.mk              # Shared Makefile rules
├── Makefile               # Top-level build configuration
├── add_module.sh          # Script to add new VHDL modules
├── .env.example           # Environment configuration template
├── .gitignore             # Git ignore rules for build artifacts
├── README.md              # This file
├── src/                   # All VHDL module implementations
│   ├── phase_clocks.vhdl  # Phase clock generator
│   ├── alu.vhdl           # Arithmetic Logic Unit
│   ├── register_file.vhdl # Register file
│   └── <module>.vhdl      # Other 8008 modules
├── sim/                   # All testbenches
│   ├── phase_clocks_tb.vhdl
│   ├── alu_tb.vhdl
│   └── <module>_tb.vhdl
├── constraints/           # Pin constraints (.lpf)
│   └── versa_ecp5.lpf     # ECP5 Versa board pins
├── build/                 # Build artifacts (git-ignored)
├── work/                  # GHDL work files (git-ignored)
└── reports/               # Synthesis/timing reports (git-ignored)
```

## Adding a New Module

Use the `add_module.sh` script to create a new VHDL module:

```bash
./add_module.sh <module_name>
```

**Example:**
```bash
./add_module.sh alu
# Creates src/alu.vhdl and sim/alu_tb.vhdl
```

This creates:
- `src/<module>.vhdl` - Module implementation template
- `sim/<module>_tb.vhdl` - Testbench template

After creating a module:
1. Edit the module and testbench files
2. Update the Makefile to include the new source files
3. Test with `make sim TEST=<module>_tb`

## Build System

The project uses a **unified Makefile system** for building and testing all modules.

### Files
- **[Makefile](Makefile)** - Top-level configuration listing all modules
- **[common.mk](common.mk)** - Shared build rules and tool configuration
  - Tool paths and environment setup
  - Simulation and synthesis workflows
  - Consistent reporting and error handling
  - Support for testing individual modules

### Configuration
Edit the top-level `Makefile` to:
- Add new modules to `RTL_SOURCES`
- Add testbenches to `ALL_TB_SOURCES`
- Set the top-level entity for synthesis
- Override default settings if needed

## Available Make Targets

All components support these standard targets:

### Primary Workflow
```bash
make sim        # Run simulation and open GTKWave (default)
make bitstream  # Build FPGA bitstream with reports
make program    # Flash to FPGA SRAM (volatile, fast)
make flash      # Flash to FPGA flash (persistent)
```

### Utilities
```bash
make sim-report # View simulation report (assertions, warnings)
make reports    # View synthesis/timing/utilization reports
make clean      # Clean simulation files
make clean-all  # Clean all build artifacts
make help       # Show all available targets
```

## Typical Workflow

### 1. Create a New Module
```bash
./add_module.sh register_file
# Creates src/register_file.vhdl and sim/register_file_tb.vhdl
```

### 2. Implement the Module
Edit the generated files:
```bash
# Edit module implementation
vim src/register_file.vhdl

# Edit testbench
vim sim/register_file_tb.vhdl
```

### 3. Update Makefile
Add to the `Makefile`:
```makefile
RTL_SOURCES = $(SRC_DIR)/register_file.vhdl \
              $(SRC_DIR)/alu.vhdl \
              ...

ALL_TB_SOURCES = $(SIM_DIR)/register_file_tb.vhdl \
                 $(SIM_DIR)/alu_tb.vhdl \
                 ...
```

### 4. Test the Module
```bash
make sim TEST=register_file_tb  # Test individual module
make sim-report                 # View test results
```

### 5. Build Complete System
```bash
make bitstream             # Full build: synth + pnr + bitstream
make reports               # View resource utilization and timing
```

### 6. Program FPGA (Optional)

**Connect the board:**
- Connect 12V power adapter
- Connect USB cable
- Set DIP switches (SW4) to Master SPI mode: `010`
  - SW4.3: Down (CFG2 = 0)
  - SW4.2: Up (CFG1 = 1)
  - SW4.1: Down (CFG0 = 0)

**Flash to hardware:**
```bash
make program               # Program SRAM (volatile, for testing)
make flash                 # Program flash (persistent, survives power cycle)
```

## SIM8-01 System Components

The SIM8-01 is the reference design from the Intel 8008 User Manual. We're implementing all support logic in FPGA to interface with real 8008 silicon.

### Current Modules
- **phase_clocks** - Two-phase non-overlapping clock generator (φ1/φ2)
  - Status: In development
  - Generates 500 kHz / 800 kHz clocks from 100 MHz FPGA oscillator
  - Files: [src/phase_clocks.vhdl](src/phase_clocks.vhdl)

### Planned Glue Logic Modules
- **state_decoder** - Decodes 8008 state outputs (S0, S1, S2) into control signals
- **timing_generator** - Generates timing and control signals for memory/I/O cycles
- **address_latch** - Latches 14-bit address from 8-bit data bus during T1/T2
- **data_bus_buffer** - Bidirectional buffer for 8008 data bus
- **memory_controller** - RAM/ROM interface logic
  - Program memory (ROM)
  - Data memory (RAM)
  - Memory timing and chip select generation
- **io_controller** - I/O port interface logic
  - Port decoding
  - I/O timing
- **interrupt_logic** - Handles 8008 INTERRUPT input
- **ready_generator** - Generates READY signal for wait states
- **sim8_01_top** - Top-level integration of complete SIM8-01 system

### Testing Strategy
1. Implement and test each module individually
2. Integrate modules progressively
3. Port/integrate softcore 8008 (Verilog→VHDL) for system validation
4. Test complete system with softcore before connecting real 8008 chip
5. Interface with real Intel 8008 silicon*

*Note: The 8008 uses PMOS technology requiring -9V/0V logic levels. A custom level shifter PCB will translate between FPGA 3.3V logic and 8008 -9V/0V logic. Design pending post-validation.

## Intel 8008 Architecture Overview

### Register Set
- **A (Accumulator)**: Primary arithmetic and logic register
- **B, C, D, E, H, L**: General-purpose registers
- **H:L Pair**: Can be used as 14-bit address pointer
- **PC (Program Counter)**: 14-bit program counter
- **Stack**: 8-level internal stack for return addresses

### Instruction Format
The 8008 uses variable-length instructions:
- 1-byte: Register operations, simple instructions
- 2-byte: Immediate data operations
- 3-byte: Jump and call instructions (14-bit addresses)

### Timing
The 8008 uses a two-phase clock system:
- **φ1 (Phi1)**: First phase clock
- **φ2 (Phi2)**: Second phase clock (non-overlapping)
- Typical cycle time: 12.5 µs @ 500 kHz (20 µs for some instructions)

## Resources

### Intel 8008 Documentation
- [Intel 8008 Datasheet (PDF)](http://www.bitsavers.org/components/intel/MCS8/98-153B_Intel_8008_Datasheet_Nov72.pdf)
- [Intel 8008 User Manual (PDF)](http://www.bitsavers.org/components/intel/MCS8/MCS-8_Users_Manual_Nov73.pdf)
- [8008 Instruction Set Reference](https://en.wikipedia.org/wiki/Intel_8008#Instruction_set)
- [The First Microprocessor (Intel Museum)](http://www.intel.com/content/www/us/en/history/museum-story-of-intel-8008.html)

### FPGA Development
- [GHDL Manual](https://ghdl.github.io/ghdl/)
- [Yosys Documentation](https://yosyshq.net/yosys/)
- [nextpnr Documentation](https://github.com/YosysHQ/nextpnr)
- [openFPGALoader](https://github.com/trabucayre/openFPGALoader)
- [ECP5-5G Versa Board User Guide](https://www.latticesemi.com/products/developmentboardsandkits/ecp55gversadevkit)
- [ECP5-5G Family Datasheet](https://www.latticesemi.com/products/fpgaprogrammabledevices/ecp5)

### OSS CAD Suite
- [OSS CAD Suite Releases](https://github.com/YosysHQ/oss-cad-suite-build/releases)
- [Installation Guide](https://github.com/YosysHQ/oss-cad-suite-build)

## Development Guidelines

When implementing 8008 components:

1. **Use the scaffolding script** (`./fpga_project.sh`) to maintain consistent structure
2. **Follow the standard directory layout** for all components
3. **Include comprehensive testbenches** with assertions
4. **Document deviations** from original 8008 specifications
5. **Test in simulation first** before synthesizing
6. **Keep timing in mind** - the original 8008 ran at 500 kHz
7. **Reference original datasheets** for accurate implementation

## Historical Context

The Intel 8008 was a milestone in computing history:
- First commercially available 8-bit microprocessor
- Led directly to the 8080, which inspired the x86 architecture
- Used in early personal computers like the Mark-8
- Demonstrated that a complete CPU could fit on a single chip

This FPGA implementation serves both as a learning tool for understanding early microprocessor architecture and as a preservation of computing history.

## Contributing

When adding new components:
1. Use `./fpga_project.sh` to create the component structure
2. Document the component's role in the 8008 architecture
3. Include timing diagrams where relevant
4. Add references to specific datasheet pages
5. Provide comprehensive test coverage

## License

See repository root for licensing information.

## Acknowledgments

- Intel Corporation for the original 8008 design and documentation
- The open-source FPGA community for the excellent toolchain
- Lattice Semiconductor for the ECP5 FPGA platform