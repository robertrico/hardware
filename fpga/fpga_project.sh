#!/bin/bash

# FPGA Project Scaffolding Script
# Creates a new FPGA project based on the blinky template structure

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if project name is provided
if [ $# -ne 1 ]; then
    echo -e "${RED}Error: Project name required${NC}"
    echo "Usage: $0 <project_name>"
    echo "Example: $0 clk_phase"
    exit 1
fi

PROJECT_NAME="$1"

# Validate project name (alphanumeric and underscores only)
if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo -e "${RED}Error: Project name must contain only letters, numbers, and underscores${NC}"
    exit 1
fi

# Check if project directory already exists
if [ -d "$PROJECT_NAME" ]; then
    echo -e "${RED}Error: Directory '$PROJECT_NAME' already exists${NC}"
    exit 1
fi

# Path to OSS CAD Suite
OSS_CAD_SUITE="/Users/$2/oss-cad-suite"

echo -e "${GREEN}Creating FPGA project: $PROJECT_NAME${NC}"
echo ""

# Create directory structure
echo "Creating directory structure..."
mkdir -p "$PROJECT_NAME"/{src,sim,constraints,build,work,docs,reports}

# Create main RTL file
echo "Creating RTL source file..."
cat > "$PROJECT_NAME/src/${PROJECT_NAME}.vhdl" << 'EOF'
-- Import the IEEE standard logic library (provides std_logic types)
library IEEE;
-- Use the std_logic_1164 package for digital logic types ('0', '1', 'Z', etc.)
use IEEE.STD_LOGIC_1164.ALL;
-- Use the numeric_std package for arithmetic operations on std_logic_vector
use IEEE.NUMERIC_STD.ALL;

-- Entity declaration: defines the external interface (inputs/outputs) of the module
entity PROJECT_NAME is
    -- Generics are like compile-time constants that can be overridden
    generic (
        CLK_FREQ : integer := 100_000_000  -- Clock frequency in Hz (100 MHz on ECP5 Versa board)
    );
    -- Ports are the actual input/output pins
    port (
        clk : in std_logic;                       -- Clock input from FPGA oscillator
        rst : in std_logic;                       -- Reset input (active high - '1' = reset)
        led : out std_logic_vector(7 downto 0)    -- 8-bit output bus for LEDs (7 down to 0)
    );
end PROJECT_NAME;

-- Architecture: describes the internal behavior/implementation of the entity
architecture rtl of PROJECT_NAME is
    -- Internal signals go here

begin
    -- Your logic implementation goes here

    -- Example: Drive all LEDs off by default
    led <= (others => '0');

end rtl;
EOF

# Replace PROJECT_NAME placeholder
sed -i '' "s/PROJECT_NAME/${PROJECT_NAME}/g" "$PROJECT_NAME/src/${PROJECT_NAME}.vhdl"

# Create testbench file
echo "Creating testbench..."
cat > "$PROJECT_NAME/sim/test.vhdl" << 'EOF'
-- Import the IEEE standard logic library (provides std_logic types)
library IEEE;
-- Use the std_logic_1164 package for digital logic types
use IEEE.STD_LOGIC_1164.ALL;
-- Use the numeric_std package for arithmetic operations
use IEEE.NUMERIC_STD.ALL;

-- Testbench entity has NO ports - it's a self-contained test environment
-- The "_tb" suffix is a common naming convention for testbenches
entity PROJECT_NAME_tb is
end PROJECT_NAME_tb;

-- Architecture for the testbench - describes the test setup
architecture sim of PROJECT_NAME_tb is

    -- Component declaration: describes the interface of the module we're testing
    component PROJECT_NAME is
        generic (
            CLK_FREQ : integer := 12000000    -- Default clock frequency
        );
        port (
            clk : in std_logic;                       -- Clock input
            rst : in std_logic;                       -- Reset input
            led : out std_logic_vector(7 downto 0)    -- 8-bit LED output
        );
    end component;

    -- Testbench signals: these connect to the component under test
    signal clk : std_logic := '0';                   -- Clock signal, starts at '0'
    signal rst : std_logic := '0';                   -- Reset signal, starts at '0' (not reset)
    signal led : std_logic_vector(7 downto 0);       -- 8-bit LED output

    -- Clock period definition for simulation
    constant CLK_PERIOD : time := 83.33 ns;  -- Period for ~12 MHz (1/12MHz = 83.33ns)

    -- For simulation, we use MUCH faster frequencies so tests don't take forever
    constant SIM_CLK_FREQ : integer := 1000;   -- 1 kHz simulated clock

    -- Signal to stop the clock generation when simulation is done
    signal sim_done : boolean := false;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: PROJECT_NAME
        generic map (
            CLK_FREQ => SIM_CLK_FREQ        -- Use 1 kHz instead of 12 MHz
        )
        port map (
            clk => clk,
            rst => rst,
            led => led
        );

    -- Clock generation process: creates a continuous square wave
    clk_process: process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Stimulus process: applies test inputs to the UUT
    stim_process: process
    begin
        -- Apply reset
        rst <= '1';
        wait for 100 ns;
        rst <= '0';

        -- Run test
        wait for 500 ms;

        -- End simulation
        sim_done <= true;
        report "Simulation completed successfully!";
        wait;
    end process;

    -- Monitor process: watches for changes on signals
    monitor: process(led)
    begin
        report "LED changed to: " & integer'image(to_integer(unsigned(led))) & " at time " & time'image(now);
    end process;

end sim;
EOF

# Replace PROJECT_NAME placeholder
sed -i '' "s/PROJECT_NAME/${PROJECT_NAME}/g" "$PROJECT_NAME/sim/test.vhdl"

# Create constraints file
echo "Creating constraints file..."
cat > "$PROJECT_NAME/constraints/versa_ecp5.lpf" << 'EOF'
# ECP5-5G Versa Development Kit Constraints
# Board: LFE5UM5G-45F-VERSA-EVN
# Device: LFE5UM5G-45F-8BG381C

# ====================================================================================
# Clock Inputs
# ====================================================================================

# 100 MHz LVDS Oscillator (X1) - General Purpose Clock
# Bank 6 - Connects to PCLKT6_0/PCLKC6_0
LOCATE COMP "clk" SITE "P3";
IOBUF PORT "clk" IO_TYPE=LVDS;

# ====================================================================================
# General Purpose LEDs (Bank 2 - 2.5V)
# Note: LEDs are ACTIVE LOW (illuminate when driven to '0')
# ====================================================================================

# LED0 - D25 (Yellow)
LOCATE COMP "led[0]" SITE "E16";
IOBUF PORT "led[0]" IO_TYPE=LVCMOS25;

# LED1 - D24 (Yellow)
LOCATE COMP "led[1]" SITE "D17";
IOBUF PORT "led[1]" IO_TYPE=LVCMOS25;

# LED2 - D22 (Green)
LOCATE COMP "led[2]" SITE "D18";
IOBUF PORT "led[2]" IO_TYPE=LVCMOS25;

# LED3 - D21 (Green)
LOCATE COMP "led[3]" SITE "E18";
IOBUF PORT "led[3]" IO_TYPE=LVCMOS25;

# LED4 - D26 (Red)
LOCATE COMP "led[4]" SITE "F17";
IOBUF PORT "led[4]" IO_TYPE=LVCMOS25;

# LED5 - D27 (Red)
LOCATE COMP "led[5]" SITE "F18";
IOBUF PORT "led[5]" IO_TYPE=LVCMOS25;

# LED6 - D28 (Red)
LOCATE COMP "led[6]" SITE "E17";
IOBUF PORT "led[6]" IO_TYPE=LVCMOS25;

# LED7 - D29 (Red)
LOCATE COMP "led[7]" SITE "F16";
IOBUF PORT "led[7]" IO_TYPE=LVCMOS25;

# ====================================================================================
# DIP Switches (SW3) - User Input (Optional)
# ====================================================================================

# SW3-1 (Bank 7 - 1.5V)
LOCATE COMP "sw[0]" SITE "H2";
IOBUF PORT "sw[0]" IO_TYPE=LVCMOS15;

# SW3-2 (Bank 7 - 1.5V)
LOCATE COMP "sw[1]" SITE "K3";
IOBUF PORT "sw[1]" IO_TYPE=LVCMOS15;

# SW3-3 (Bank 7 - 1.5V)
LOCATE COMP "sw[2]" SITE "G3";
IOBUF PORT "sw[2]" IO_TYPE=LVCMOS15;

# SW3-4 (Bank 7 - 1.5V)
LOCATE COMP "sw[3]" SITE "F2";
IOBUF PORT "sw[3]" IO_TYPE=LVCMOS15;

# SW3-5 (Bank 2 - 2.5V)
LOCATE COMP "sw[4]" SITE "J18";
IOBUF PORT "sw[4]" IO_TYPE=LVCMOS25;

# SW3-6 (Bank 2 - 2.5V)
LOCATE COMP "sw[5]" SITE "K18";
IOBUF PORT "sw[5]" IO_TYPE=LVCMOS25;

# SW3-7 (Bank 2 - 2.5V)
LOCATE COMP "sw[6]" SITE "K19";
IOBUF PORT "sw[6]" IO_TYPE=LVCMOS25;

# SW3-8 (Bank 2 - 2.5V)
LOCATE COMP "sw[7]" SITE "K20";
IOBUF PORT "sw[7]" IO_TYPE=LVCMOS25;

# ====================================================================================
# Configuration
# ====================================================================================

# These apply to the entire design
SYSCONFIG CONFIG_IOVOLTAGE=3.3 COMPRESS_CONFIG=ON MCCLK_FREQ=62;
EOF

# Create Makefile
echo "Creating Makefile..."
cat > "$PROJECT_NAME/Makefile" << 'EOF'
# PROJECT_NAME FPGA Project Makefile
# This file defines project-specific configuration and includes common build rules

#==========================================
# Project Configuration
#==========================================
# Top-level entity and testbench names
TOP_ENTITY = PROJECT_NAME
TB_ENTITY = PROJECT_NAME_tb

# Source files
RTL_SOURCES = $(SRC_DIR)/PROJECT_NAME.vhdl
TB_SOURCES = $(SIM_DIR)/test.vhdl

#==========================================
# Optional Overrides
#==========================================
# Uncomment and modify these if you need non-default values:
# SIM_STOP_TIME = 2ms        # Simulation duration (default: 1ms)
# FPGA_DEVICE = um5g-45k     # FPGA device (default: um5g-45k)
# FPGA_PACKAGE = CABGA381    # Package type (default: CABGA381)
# FPGA_SPEED = 8             # Speed grade (default: 8)
# GHDL_FLAGS = --std=08      # GHDL flags (default: --std=08)

#==========================================
# Include Common Build Rules
#==========================================
include ../common.mk
EOF

# Replace placeholders in Makefile
sed -i '' "s/PROJECT_NAME/${PROJECT_NAME}/g" "$PROJECT_NAME/Makefile"

# Create README.md
echo "Creating README.md..."
cat > "$PROJECT_NAME/README.md" << 'EOF'
# PROJECT_NAME - ECP5-5G Versa Development Kit

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

## Project Structure

```
PROJECT_NAME/
├── Makefile              # Build system
├── README.md             # This file
├── constraints/
│   └── versa_ecp5.lpf    # Pin constraints for ECP5 Versa board
├── src/
│   └── PROJECT_NAME.vhdl # RTL source code
├── sim/
│   └── test.vhdl         # Testbench
├── build/                # Generated build artifacts
├── work/                 # GHDL work directory
└── reports/              # Synthesis/timing reports
```

## Quick Start

### 1. Simulate
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
make clean               # Clean simulation files
make clean-all           # Clean everything
make help                # Show all targets
```

## Development

Edit the RTL source file [src/PROJECT_NAME.vhdl](src/PROJECT_NAME.vhdl) to implement your design.

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
EOF

# Replace PROJECT_NAME in README
sed -i '' "s/PROJECT_NAME/${PROJECT_NAME}/g" "$PROJECT_NAME/README.md"

echo ""
echo -e "${GREEN}Project '$PROJECT_NAME' created successfully!${NC}"
echo ""
echo "Next steps:"
echo "  1. cd $PROJECT_NAME"
echo "  2. Edit src/${PROJECT_NAME}.vhdl  # Implement your design"
echo "  3. Edit sim/test.vhdl         # Add test cases"
echo "  4. make sim                   # Run simulation"
echo "  5. make bitstream             # Build for FPGA"
echo "  6. make program               # Flash to hardware"
echo ""
echo -e "${YELLOW}Documentation:${NC} See $PROJECT_NAME/README.md"
echo ""
