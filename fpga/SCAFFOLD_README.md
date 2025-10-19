# FPGA Project Scaffolding Tool

## Overview

The `fpga_project.sh` script creates a new FPGA project with the same structure and toolchain as the blinky project. It scaffolds everything you need to start a new VHDL project for the Lattice ECP5-5G Versa Development Kit.

## Usage

```bash
./fpga_project.sh <project_name>
```

### Example

```bash
./fpga_project.sh clk_phase
```

This creates a complete project structure:

```
clk_phase/
├── Makefile                    # Complete build system
├── README.md                   # Project-specific documentation
├── .gitignore                  # Sensible defaults for git
├── src/
│   └── clk_phase.vhdl         # Your RTL source (template)
├── sim/
│   └── test.vhdl              # Testbench (template)
├── constraints/
│   └── versa_ecp5.lpf         # Pin constraints for ECP5 Versa
├── install_scripts/
│   └── check_toolchain.sh     # Verify toolchain installation
├── build/                      # Build artifacts (generated)
├── work/                       # GHDL work directory (generated)
├── reports/                    # Synthesis/timing reports (generated)
└── docs/                       # Your documentation
```

## Features

### Automatic Name Substitution
- Replaces all instances of placeholder names with your project name
- Updates entity names, file names, and documentation
- Creates properly named VHDL files and testbenches

### Complete Toolchain Integration
- Pre-configured Makefile with all targets
- GHDL simulation setup
- Yosys synthesis configuration
- nextpnr-ecp5 place and route
- openFPGALoader programming scripts
- GTKWave waveform viewing

### Ready-to-Use Templates
- RTL source with basic entity/architecture structure
- Testbench with clock generation and stimulus
- Complete pin constraints for ECP5-5G Versa board
- All 8 LEDs and 8 DIP switches pre-configured

### Development Workflow
After creating a project:

```bash
cd <project_name>

# 1. Verify toolchain
make check-tools

# 2. Edit your design
vim src/<project_name>.vhdl

# 3. Edit testbench
vim sim/test.vhdl

# 4. Simulate
make sim                 # Runs GHDL and opens GTKWave

# 5. Build for FPGA
make bitstream           # Synthesizes to bitstream
make reports             # View timing/utilization

# 6. Program hardware
make program             # Flash to SRAM (volatile)
make flash               # Flash to persistent memory
```

## What Gets Created

### Source Files
- **src/<project_name>.vhdl** - RTL template with:
  - Clock and reset inputs
  - 8-bit LED output
  - Proper VHDL structure and comments
  - Ready to customize

### Testbench
- **sim/test.vhdl** - Complete testbench with:
  - Clock generation
  - Reset stimulus
  - Component instantiation
  - Monitor process for debugging
  - VCD waveform generation

### Build System
- **Makefile** - Full build automation:
  - Simulation targets (analyze, elaborate, sim)
  - FPGA build targets (bitstream, program, flash)
  - Report generation (timing, utilization)
  - Clean targets
  - Help documentation

### Constraints
- **constraints/versa_ecp5.lpf** - Complete pin assignments:
  - 100 MHz LVDS clock (Pin P3)
  - 8x LEDs (active low)
  - 8x DIP switches
  - Proper I/O types and banks

### Documentation
- **README.md** - Project-specific documentation
- **install_scripts/check_toolchain.sh** - Toolchain verification

## Requirements

- OSS CAD Suite installed at `/Users/hackbook/oss-cad-suite`
- Bash shell
- macOS (tested) or Linux

## Project Name Rules

Project names must:
- Contain only letters, numbers, and underscores
- Not already exist as a directory
- Be valid VHDL entity names (start with letter, no spaces)

## Comparison with Blinky

The scaffold creates an identical structure to blinky:
- ✅ Same Makefile targets and workflow
- ✅ Same directory structure
- ✅ Same toolchain configuration
- ✅ Same pin constraints
- ✅ Same build system

The only differences:
- Clean template instead of blinky implementation
- Project-specific names throughout
- Empty logic (ready for your design)

## Tips

### Quick Start After Scaffolding
```bash
# Create project
./fpga_project.sh my_design

# Jump right into development
cd my_design
make sim              # Verify template works
# Edit src/my_design.vhdl
make sim              # Test your changes
make bitstream        # Build for FPGA
```

### Multiple Projects
You can create as many projects as you need:
```bash
./fpga_project.sh uart_tx
./fpga_project.sh spi_master
./fpga_project.sh pwm_controller
```

Each will be independent with its own build system.

### Customization
After creating a project, customize:
- RTL source for your design
- Testbench for your test cases
- Constraints if using different pins
- Makefile variables (clock frequency, device size, etc.)

## Troubleshooting

### "Directory already exists"
Remove the old directory first:
```bash
rm -rf <project_name>
./fpga_project.sh <project_name>
```

### "Invalid project name"
Use only alphanumeric characters and underscores:
```bash
# Good
./fpga_project.sh my_project
./fpga_project.sh clk_phase_detector

# Bad
./fpga_project.sh my-project     # No hyphens
./fpga_project.sh "my project"   # No spaces
```

### Tools not found after creating project
Update the OSS_CAD_SUITE path in the generated Makefile:
```makefile
OSS_CAD_SUITE = /your/path/to/oss-cad-suite
```

## License

This scaffolding tool is provided as-is for creating FPGA projects with open-source tools.
