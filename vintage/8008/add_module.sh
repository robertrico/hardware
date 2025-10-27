#!/bin/bash

# FPGA Module Creation Script for Intel 8008 Vintage CPU
# Creates a new VHDL module for the 8008 implementation

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if module name is provided
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Invalid arguments${NC}"
    echo "Usage: $0 <module_name>"
    echo "Example: $0 alu"
    echo "Example: $0 register_file"
    echo ""
    echo "Creates a new VHDL module in the src/ directory with corresponding testbench"
    exit 1
fi

MODULE_NAME="$1"

# Validate module name (alphanumeric and underscores only)
if [[ ! "$MODULE_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo -e "${RED}Error: Module name must contain only letters, numbers, and underscores${NC}"
    exit 1
fi

# Check if module already exists
if [ -f "src/${MODULE_NAME}.vhdl" ]; then
    echo -e "${RED}Error: Module 'src/${MODULE_NAME}.vhdl' already exists${NC}"
    exit 1
fi

echo -e "${GREEN}Creating Intel 8008 module: $MODULE_NAME${NC}"
echo ""

# Ensure directories exist
echo "Ensuring directory structure..."
mkdir -p src sim

# Create main RTL file
echo "Creating module file: src/${MODULE_NAME}.vhdl"
cat > "src/${MODULE_NAME}.vhdl" << EOF
-- Intel 8008 Component: ${MODULE_NAME}
-- Part of the vintage 8008 CPU implementation
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ${MODULE_NAME} is
    port (
        clk : in std_logic;                       -- System clock
        rst : in std_logic;                       -- Active-high reset
        -- Add your module-specific ports here

        -- Example input/output ports:
        -- data_in  : in  std_logic_vector(7 downto 0);
        -- data_out : out std_logic_vector(7 downto 0);
        -- enable   : in  std_logic;
        -- ready    : out std_logic
    );
end ${MODULE_NAME};

architecture rtl of ${MODULE_NAME} is
    -- Internal signals and components

begin
    -- Module implementation

    process(clk, rst)
    begin
        if rst = '1' then
            -- Reset logic

        elsif rising_edge(clk) then
            -- Clocked logic

        end if;
    end process;

end rtl;
EOF

# Create testbench file
echo "Creating testbench: sim/${MODULE_NAME}_tb.vhdl"
cat > "sim/${MODULE_NAME}_tb.vhdl" << EOF
-- Testbench for Intel 8008 Component: ${MODULE_NAME}
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ${MODULE_NAME}_tb is
end ${MODULE_NAME}_tb;

architecture sim of ${MODULE_NAME}_tb is

    -- Component declaration
    component ${MODULE_NAME} is
        port (
            clk : in std_logic;
            rst : in std_logic
            -- Add your module's ports here to match the actual module
        );
    end component;

    -- Testbench signals
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    -- Add signals to connect to the module's ports

    -- Clock period (simulating ~12 MHz for fast simulation)
    constant CLK_PERIOD : time := 83.33 ns;

    -- Simulation control
    signal sim_done : boolean := false;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: ${MODULE_NAME}
        port map (
            clk => clk,
            rst => rst
            -- Map your module's ports here
        );

    -- Clock generation
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

    -- Stimulus process
    stim_process: process
    begin
        -- Apply reset
        report "Starting test for ${MODULE_NAME}";
        rst <= '1';
        wait for 200 ns;
        rst <= '0';
        wait for 100 ns;

        -- Add your test cases here
        report "Add test cases for ${MODULE_NAME}";

        -- Run for a while
        wait for 1 ms;

        -- End simulation
        report "Test completed for ${MODULE_NAME}";
        sim_done <= true;
        wait;
    end process;

    -- Optional: Monitor process for debugging
    -- monitor: process
    -- begin
    --     wait on <signal_to_monitor>;
    --     report "Signal changed at time " & time'image(now);
    -- end process;

end sim;
EOF

echo ""
echo -e "${GREEN}Module '$MODULE_NAME' created successfully!${NC}"
echo ""
echo "Files created:"
echo "  - src/${MODULE_NAME}.vhdl       (module implementation)"
echo "  - sim/${MODULE_NAME}_tb.vhdl    (testbench)"
echo ""
echo "Next steps:"
echo "  1. Edit src/${MODULE_NAME}.vhdl to implement your module"
echo "  2. Edit sim/${MODULE_NAME}_tb.vhdl to add test cases"
echo "  3. Update the Makefile RTL_SOURCES to include src/${MODULE_NAME}.vhdl"
echo "  4. Update the Makefile ALL_TB_SOURCES to include sim/${MODULE_NAME}_tb.vhdl"
echo "  5. Run 'make sim TEST=${MODULE_NAME}_tb' to test the module"
echo ""
