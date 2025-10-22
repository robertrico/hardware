# FPGA Projects

Collection of FPGA projects for the Lattice ECP5-5G Versa Development Kit using open-source tools.

## Hardware

**Board**: Lattice ECP5-5G Versa Development Kit
**Device**: LFE5UM5G-45F-8BG381C
**Package**: 381-ball caBGA
**FPGA**: ECP5-5G (45k LUTs, SERDES capable)

## Toolchain

This repository uses the open-source FPGA toolchain:

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

### Machine-Specific Configuration

The build system uses a `.env` file to configure machine-specific settings like your username.

**First-time setup:**
```bash
cd fpga/
cp .env.example .env
# Edit .env and set your username
```

**Example `.env` file:**
```bash
# Set to your macOS username (e.g., hambook or hackbook)
USERNAME=hackbook
```

The Makefile will automatically use `/Users/$(USERNAME)/oss-cad-suite` as the tool path. You can also override the full path if needed:
```bash
# Alternative: set full path
OSS_CAD_SUITE=/custom/path/to/oss-cad-suite
```

## Build System Structure

All projects use a **shared Makefile system** for consistency and maintainability.

### Common Build Rules ([common.mk](common.mk))
- Shared build rules, tools, and targets across all projects
- Centralized configuration for OSS CAD Suite path
- Standard simulation and synthesis workflows
- Consistent reporting and error handling

### Project-Specific Makefiles
Each project has a minimal Makefile (~20 lines) that:
- Defines project configuration (entity names, source files)
- Includes `../common.mk` for all build rules
- Can override defaults if needed (simulation time, FPGA device, etc.)

**Example project Makefile**:
```makefile
# Project Configuration
TOP_ENTITY = my_project
TB_ENTITY = my_project_tb
RTL_SOURCES = $(SRC_DIR)/my_project.vhdl
TB_SOURCES = $(SIM_DIR)/test.vhdl

# Optional Overrides
# SIM_STOP_TIME = 2ms        # Default: 1ms
# FPGA_DEVICE = um5g-45k     # Default: um5g-45k

# Include Common Build Rules
include ../common.mk
```

### Available Make Targets

All projects support these standard targets:

#### Primary Workflow
```bash
make sim        # Run simulation and open GTKWave (default)
make bitstream  # Build FPGA bitstream with reports
make program    # Flash to FPGA SRAM (volatile, fast)
make flash      # Flash to FPGA flash (persistent)
```

#### Utilities
```bash
make sim-report # View simulation report (assertions, warnings)
make reports    # View synthesis/timing/utilization reports
make clean      # Clean simulation files
make clean-all  # Clean all build artifacts
make help       # Show all available targets
```

#### Advanced Options
```bash
make sim SIM_STOP_TIME=2ms  # Override simulation duration
```

## Creating a New Project

Use the scaffolding script to create a new project with the proper structure:

```bash
./fpga_project.sh <project_name> <username>
```

**Example**:
```bash
./fpga_project.sh my_counter hambook
cd my_counter
make sim        # Run simulation
```

This creates:
```
my_counter/
├── Makefile                # Minimal project-specific Makefile
├── README.md               # Project documentation
├── src/
│   └── my_counter.vhdl     # RTL source code
├── sim/
│   └── test.vhdl           # Testbench
├── constraints/
│   └── versa_ecp5.lpf      # Pin constraints for ECP5 Versa
├── docs/                   # Project documentation
├── build/                  # Build artifacts (git-ignored)
├── work/                   # GHDL work files (git-ignored)
└── reports/                # Synthesis/timing reports (git-ignored)
```

## Project Structure

### Standard Directory Layout
```
fpga/
├── common.mk              # Shared Makefile rules
├── fpga_project.sh        # Project scaffolding script
├── README.md              # This file
├── PROJECTS.md            # Progressive learning path
├── blinky/                # Example: LED blinker
├── binary_counter/        # Example: 8-bit counter
└── <your_project>/        # Your project
```

### File Organization
Each project follows this structure:
- `src/` - RTL source code (VHDL)
- `sim/` - Testbenches for simulation
- `constraints/` - Pin constraint files (.lpf)
- `docs/` - Project-specific documentation
- `build/` - Generated bitstreams (git-ignored)
- `work/` - GHDL work directory (git-ignored)
- `reports/` - Synthesis/timing reports (git-ignored)

## Typical Workflow

### 1. Create Project
```bash
./fpga_project.sh my_project hambook
cd my_project
```

### 2. Implement Design
Edit `src/my_project.vhdl` and `sim/test.vhdl`

### 3. Simulate
```bash
make sim                   # Runs simulation and opens GTKWave
make sim-report            # View simulation report
```

### 4. Synthesize
```bash
make bitstream             # Full build: synth + pnr + bitstream
make reports               # View resource utilization and timing
```

### 5. Program FPGA

**Connect the board:**
- Connect 12V power adapter
- Connect USB cable (for programming)
- Set DIP switches (SW4) to Master SPI mode: `010`
  - SW4.3: Down (CFG2 = 0)
  - SW4.2: Up (CFG1 = 1)
  - SW4.1: Down (CFG0 = 0)

**Flash to hardware:**
```bash
make program               # Program SRAM (volatile, for testing)
make flash                 # Program flash (persistent, survives power cycle)
```

## Learning Path

See [PROJECTS.md](PROJECTS.md) for a progressive series of projects that build FPGA skills from basics to advanced FSM design.

**Current Projects:**
- ✅ **blinky** - Single LED blinker (complete)
- ✅ **knight_rider** - KITT-style LED scanner (complete)
- 🛠️ **binary_counter** - 8-bit binary counter (ready for hardware)

**Next Projects:**
- Button-controlled LED (debouncing)
- Multi-button LED control
- Pattern sequencer
- Traffic light controller (final comprehensive FSM project)

## Board Configuration

### Pin Mapping (versa_ecp5.lpf)
All projects include a constraints file with standard pin mappings:
- **Clock**: 100 MHz LVDS oscillator (P3)
- **LEDs**: 8 general-purpose LEDs (active-low)
- **Switches**: 8 DIP switches (SW3)

See individual project constraint files for specific mappings.

### Configuration Mode (SW4)
For normal programming, set to **Master SPI** mode:
- SW4.3: Down (CFG2 = 0)
- SW4.2: Up (CFG1 = 1)
- SW4.1: Down (CFG0 = 0)

## Customization

### Override Common Settings
Projects can override common.mk defaults in their Makefile:

```makefile
# Project-specific overrides
SIM_STOP_TIME = 5ms        # Longer simulation
FPGA_DEVICE = um5g-25k     # Different device size
GHDL_FLAGS = --std=08      # VHDL-2008 standard
```

### Change OSS CAD Suite Path
Edit [common.mk](common.mk) line 17:
```makefile
OSS_CAD_SUITE ?= /Users/hambook/oss-cad-suite
```

## Troubleshooting

### Simulation Issues
```bash
make clean                 # Clean simulation files
make sim                   # Re-run simulation
make sim-report            # Check for assertion failures
```

### Synthesis Issues
```bash
make clean-all             # Clean all build files
make bitstream             # Rebuild from scratch
make reports               # Check timing/utilization
```

### Programming Issues
- Verify board is powered (12V adapter)
- Check USB connection
- Verify SW4 switches are in Master SPI mode (`010`)
- Try `make program` (SRAM) before `make flash`

## Resources

### Documentation
- [GHDL Manual](https://ghdl.github.io/ghdl/)
- [Yosys Documentation](https://yosyshq.net/yosys/)
- [nextpnr Documentation](https://github.com/YosysHQ/nextpnr)
- [openFPGALoader](https://github.com/trabucayre/openFPGALoader)
- [ECP5-5G Versa Board User Guide](https://www.latticesemi.com/products/developmentboardsandkits/ecp55gversadevkit)
- [ECP5-5G Family Datasheet](https://www.latticesemi.com/products/fpgaprogrammabledevices/ecp5)

### OSS CAD Suite
- [OSS CAD Suite Releases](https://github.com/YosysHQ/oss-cad-suite-build/releases)
- [Installation Guide](https://github.com/YosysHQ/oss-cad-suite-build)

## Contributing

When adding new projects:
1. Use `./fpga_project.sh` to maintain consistent structure
2. Follow the standard directory layout
3. Include comprehensive testbenches
4. Document any project-specific requirements in project README
5. Update [PROJECTS.md](PROJECTS.md) if it's part of the learning path

## License

See individual project directories for licensing information.
