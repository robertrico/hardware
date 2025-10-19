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
