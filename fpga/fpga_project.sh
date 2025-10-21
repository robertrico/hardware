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
OSS_CAD_SUITE="/Users/hackbook/oss-cad-suite"

echo -e "${GREEN}Creating FPGA project: $PROJECT_NAME${NC}"
echo ""

# Create directory structure
echo "Creating directory structure..."
mkdir -p "$PROJECT_NAME"/{src,sim,constraints,build,work,docs,install_scripts,reports}

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
        CLK_FREQ : integer := 12000000  -- Clock frequency in Hz (12 MHz on ECP5 Versa board)
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
# FPGA Build and Simulation Makefile

#==========================================
# Environment Setup
#==========================================
# OSS CAD Suite path
OSS_CAD_SUITE = OSS_CAD_SUITE_PATH
SHELL := /bin/bash
export PATH := $(OSS_CAD_SUITE)/bin:$(PATH)

#==========================================
# Tools
#==========================================
GHDL = $(OSS_CAD_SUITE)/bin/ghdl
YOSYS = $(OSS_CAD_SUITE)/bin/yosys
NEXTPNR = $(OSS_CAD_SUITE)/bin/nextpnr-ecp5
ECPPACK = $(OSS_CAD_SUITE)/bin/ecppack
OPENFPGALOADER = $(OSS_CAD_SUITE)/bin/openFPGALoader
GTKWAVE = $(OSS_CAD_SUITE)/bin/gtkwave

#==========================================
# Directories
#==========================================
SRC_DIR = src
SIM_DIR = sim
BUILD_DIR = build
WORK_DIR = work
CONSTRAINTS_DIR = constraints
REPORTS_DIR = reports

#==========================================
# Source files
#==========================================
RTL_SOURCES = $(SRC_DIR)/PROJECT_NAME.vhdl
TB_SOURCES = $(SIM_DIR)/test.vhdl
TOP_ENTITY = PROJECT_NAME
TB_ENTITY = PROJECT_NAME_tb

# Constraint files (create if needed)
LPF_FILE = $(CONSTRAINTS_DIR)/versa_ecp5.lpf

#==========================================
# FPGA Configuration
#==========================================
# Lattice ECP5-5G Versa board defaults (LFE5UM5G-45F-VERSA-EVN)
FPGA_DEVICE = um5g-45k
FPGA_PACKAGE = CABGA381
FPGA_SPEED = 8

#==========================================
# Build outputs
#==========================================
JSON_FILE = $(BUILD_DIR)/$(TOP_ENTITY).json
TEXTCFG_FILE = $(BUILD_DIR)/$(TOP_ENTITY).config
BITSTREAM_FILE = $(BUILD_DIR)/$(TOP_ENTITY).bit

# Report files
SYNTH_REPORT = $(REPORTS_DIR)/synthesis.txt
PNR_REPORT = $(REPORTS_DIR)/pnr.txt
TIMING_REPORT = $(REPORTS_DIR)/timing.txt
UTILIZATION_REPORT = $(REPORTS_DIR)/utilization.txt

#==========================================
# Simulation parameters
#==========================================
SIM_STOP_TIME = 1ms
SIM_OUTPUT = $(SIM_DIR)/output.txt
VCD_FILE = $(SIM_DIR)/$(TB_ENTITY).vcd
GTKW_FILE = $(SIM_DIR)/$(TB_ENTITY).gtkw
GHDL_FLAGS = --std=08

#==========================================
# Default Targets
#==========================================
.PHONY: all
all: sim

#==========================================
# Directory Creation
#==========================================
$(WORK_DIR):
	@mkdir -p $(WORK_DIR)

$(BUILD_DIR):
	@mkdir -p $@

# Note: reports directory creation (avoid naming conflict with .PHONY target)
.PHONY: create-reports-dir
create-reports-dir:
	@mkdir -p $(REPORTS_DIR)

#==========================================
# Simulation Flow
#==========================================

# Analyze RTL sources
.PHONY: analyze-rtl
analyze-rtl: $(WORK_DIR)
	@echo "Analyzing RTL sources..."
	$(GHDL) -a $(GHDL_FLAGS) --workdir=$(WORK_DIR) $(RTL_SOURCES)

# Analyze testbench sources
.PHONY: analyze-tb
analyze-tb: analyze-rtl
	@echo "Analyzing testbench sources..."
	$(GHDL) -a $(GHDL_FLAGS) --workdir=$(WORK_DIR) $(TB_SOURCES)

# Elaborate (build) testbench
.PHONY: elaborate
elaborate: analyze-tb
	@echo "Elaborating $(TB_ENTITY)..."
	$(GHDL) -e $(GHDL_FLAGS) --workdir=$(WORK_DIR) $(TB_ENTITY)

# Run simulation, generate VCD, and open GTKWave
.PHONY: sim
sim: elaborate
	@echo "Running simulation with VCD output..."
	$(GHDL) -r $(GHDL_FLAGS) --workdir=$(WORK_DIR) $(TB_ENTITY) --stop-time=$(SIM_STOP_TIME) --vcd=$(VCD_FILE)
	@echo "VCD file saved to $(VCD_FILE)"
	@echo "Opening waveform in GTKWave..."
	@if [ -f "$(GTKW_FILE)" ]; then \
		nohup $(GTKWAVE) $(GTKW_FILE) > /dev/null 2>&1 & \
	else \
		nohup $(GTKWAVE) $(VCD_FILE) > /dev/null 2>&1 & \
	fi

#==========================================
# FPGA Synthesis Flow
#==========================================

# Synthesis: VHDL -> JSON netlist (using GHDL synth)
$(JSON_FILE): $(RTL_SOURCES) | $(BUILD_DIR) create-reports-dir
	@echo "Analyzing VHDL for synthesis..."
	$(GHDL) -a $(GHDL_FLAGS) $(RTL_SOURCES)
	@echo "Synthesizing with GHDL and Yosys..."
	$(GHDL) --synth $(GHDL_FLAGS) --out=verilog $(TOP_ENTITY) > $(BUILD_DIR)/$(TOP_ENTITY).v
	@echo "Running Yosys synthesis..."
	$(YOSYS) -p "read_verilog $(BUILD_DIR)/$(TOP_ENTITY).v; synth_ecp5 -top $(TOP_ENTITY) -json $(JSON_FILE)" 2>&1 | tee $(SYNTH_REPORT)
	@echo "Synthesis report saved to $(SYNTH_REPORT)"


# Place & Route: JSON -> config file
$(TEXTCFG_FILE): $(JSON_FILE) | create-reports-dir
	@echo "Running place and route..."
	@if [ -f "$(LPF_FILE)" ]; then \
		$(NEXTPNR) --$(FPGA_DEVICE) --package $(FPGA_PACKAGE) --speed $(FPGA_SPEED) \
			--json $(JSON_FILE) --textcfg $(TEXTCFG_FILE) --lpf $(LPF_FILE) --lpf-allow-unconstrained \
			2>&1 | tee $(PNR_REPORT); \
	else \
		echo "Warning: No constraints file found at $(LPF_FILE)"; \
		echo "Running without pin constraints..."; \
		$(NEXTPNR) --$(FPGA_DEVICE) --package $(FPGA_PACKAGE) --speed $(FPGA_SPEED) \
			--json $(JSON_FILE) --textcfg $(TEXTCFG_FILE) \
			2>&1 | tee $(PNR_REPORT); \
	fi
	@echo "Place and route report saved to $(PNR_REPORT)"
	@echo ""
	@echo "Extracting timing report..."
	@grep -A 50 "Critical path report" $(PNR_REPORT) > $(TIMING_REPORT) || true
	@grep "Max frequency\|Max delay\|Slack" $(PNR_REPORT) >> $(TIMING_REPORT) || true
	@echo "Timing report saved to $(TIMING_REPORT)"
	@echo ""
	@echo "Extracting utilization report..."
	@grep -B 2 -A 30 "Device utilisation" $(PNR_REPORT) > $(UTILIZATION_REPORT) || true
	@echo "Utilization report saved to $(UTILIZATION_REPORT)"


# Pack: config -> bitstream
$(BITSTREAM_FILE): $(TEXTCFG_FILE)
	@echo "Generating bitstream..."
	$(ECPPACK) $(TEXTCFG_FILE) $(BITSTREAM_FILE)

.PHONY: bitstream
bitstream: $(BITSTREAM_FILE)

# Program to FPGA SRAM (volatile, fast for testing)
.PHONY: program
program: $(BITSTREAM_FILE)
	@echo "Programming FPGA SRAM (volatile)..."
	$(OPENFPGALOADER) -c ft2232 -m $(BITSTREAM_FILE)

# Program to FPGA flash (persistent, survives power cycle)
.PHONY: flash
flash: $(BITSTREAM_FILE)
	@echo "Programming FPGA flash (persistent)..."
	$(OPENFPGALOADER) -b versa_ecp5 $(BITSTREAM_FILE)

#==========================================
# Utility Targets
#==========================================

# View build reports
.PHONY: reports
reports:
	@if [ ! -d "$(REPORTS_DIR)" ]; then \
		echo "No reports found. Run 'make bitstream' first."; \
		exit 1; \
	fi
	@echo "=========================================="
	@echo "FPGA Build Reports"
	@echo "=========================================="
	@echo ""
	@if [ -f "$(UTILIZATION_REPORT)" ]; then \
		echo "--- Resource Utilization ---"; \
		cat $(UTILIZATION_REPORT); \
		echo ""; \
	fi
	@if [ -f "$(TIMING_REPORT)" ]; then \
		echo "--- Timing Summary ---"; \
		head -20 $(TIMING_REPORT); \
		echo ""; \
	fi
	@echo "Full reports available at:"
	@echo "  Synthesis:    $(SYNTH_REPORT)"
	@echo "  PnR:          $(PNR_REPORT)"
	@echo "  Timing:       $(TIMING_REPORT)"
	@echo "  Utilization:  $(UTILIZATION_REPORT)"

# Check toolchain
.PHONY: check-tools
check-tools:
	@./install_scripts/check_toolchain.sh

# Clean generated files
.PHONY: clean
clean:
	@echo "Cleaning simulation files..."
	@$(GHDL) --clean $(GHDL_FLAGS) --workdir=$(WORK_DIR) 2>/dev/null || true
	@rm -rf $(WORK_DIR)
	@rm -f $(TB_ENTITY)
	@rm -f *.cf
	@rm -f $(VCD_FILE)

# Clean everything including FPGA build
.PHONY: clean-all distclean
clean-all distclean: clean
	@echo "Cleaning all build files..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(REPORTS_DIR)

# Help target
.PHONY: help
help:
	@echo "FPGA Build and Simulation Makefile"
	@echo ""
	@echo "=== Primary Workflow ==="
	@echo "  make sim        - Run simulation and open GTKWave (default)"
	@echo "  make bitstream  - Build FPGA bitstream with reports"
	@echo "  make program    - Flash to FPGA SRAM (volatile, fast)"
	@echo "  make flash      - Flash to FPGA flash (persistent)"
	@echo ""
	@echo "=== Utility Targets ==="
	@echo "  make reports    - View synthesis/timing/utilization reports"
	@echo "  make clean      - Remove simulation files"
	@echo "  make clean-all  - Remove all build files and reports"
	@echo "  make help       - Show this help"
	@echo ""
	@echo "=== Advanced Options ==="
	@echo "  SIM_STOP_TIME   - Simulation duration (default: $(SIM_STOP_TIME))"
	@echo "  Example: make sim SIM_STOP_TIME=2ms"
	@echo ""
	@echo "=== Typical Workflow ==="
	@echo "  1. make sim         # Verify design in simulation"
	@echo "  2. make bitstream   # Synthesize for FPGA"
	@echo "  3. make reports     # Check timing/utilization"
	@echo "  4. make program     # Flash to SRAM (test)"
	@echo "  5. make flash       # Flash to persistent memory (deploy)"
EOF

# Replace placeholders in Makefile
sed -i '' "s|OSS_CAD_SUITE_PATH|${OSS_CAD_SUITE}|g" "$PROJECT_NAME/Makefile"
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

Verify installation:
```bash
make check-tools
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

# Create check_toolchain.sh
echo "Creating toolchain check script..."
cat > "$PROJECT_NAME/install_scripts/check_toolchain.sh" << 'EOF'
#!/bin/bash

# FPGA Toolchain Check Script
# Verifies that all required tools are installed and accessible

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Checking FPGA toolchain installation..."
echo ""

# Array to track missing tools
MISSING_TOOLS=()

# Function to check if a command exists
check_tool() {
    local tool=$1
    local name=$2

    if command -v "$tool" &> /dev/null; then
        local version=$($tool --version 2>&1 | head -n 1)
        echo -e "${GREEN}✓${NC} $name: $version"
        return 0
    else
        echo -e "${RED}✗${NC} $name: NOT FOUND"
        MISSING_TOOLS+=("$name")
        return 1
    fi
}

# Check each tool
check_tool "ghdl" "GHDL"
check_tool "yosys" "Yosys"
check_tool "nextpnr-ecp5" "nextpnr-ecp5"
check_tool "ecppack" "ecppack"
check_tool "openFPGALoader" "openFPGALoader"
check_tool "gtkwave" "GTKWave"

echo ""

# Report results
if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    echo -e "${GREEN}All tools are installed and ready!${NC}"
    exit 0
else
    echo -e "${RED}Missing tools: ${MISSING_TOOLS[*]}${NC}"
    echo ""
    echo -e "${YELLOW}Install OSS CAD Suite:${NC}"
    echo "  brew install --cask oss-cad-suite"
    echo "  Or download from: https://github.com/YosysHQ/oss-cad-suite-build/releases"
    exit 1
fi
EOF

chmod +x "$PROJECT_NAME/install_scripts/check_toolchain.sh"

# Create .gitignore
echo "Creating .gitignore..."
cat > "$PROJECT_NAME/.gitignore" << 'EOF'
# GHDL work files
work/
*.cf

# Build artifacts
build/
reports/

# Simulation outputs
sim/*.vcd
sim/*.ghw
sim/output.txt

# GTKWave save files
*.gtkw

# Editor files
*.swp
*.swo
*~
.DS_Store

# Testbench executables
*_tb
e~*.lst
EOF

echo ""
echo -e "${GREEN}Project '$PROJECT_NAME' created successfully!${NC}"
echo ""
echo "Next steps:"
echo "  1. cd $PROJECT_NAME"
echo "  2. make check-tools           # Verify toolchain"
echo "  3. Edit src/${PROJECT_NAME}.vhdl  # Implement your design"
echo "  4. Edit sim/test.vhdl         # Add test cases"
echo "  5. make sim                   # Run simulation"
echo "  6. make bitstream             # Build for FPGA"
echo "  7. make program               # Flash to hardware"
echo ""
echo -e "${YELLOW}Documentation:${NC} See $PROJECT_NAME/README.md"
echo ""
