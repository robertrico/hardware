#!/bin/bash

echo "========================================="
echo "FPGA Toolchain Verification"
echo "========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_tool() {
    local tool=$1
    local version_cmd=$2
    
    if command -v $tool &> /dev/null; then
        echo -e "${GREEN}✓${NC} $tool found"
        if [ ! -z "$version_cmd" ]; then
            eval $version_cmd 2>&1 | head -n 1 | sed 's/^/  /'
        fi
        return 0
    else
        echo -e "${RED}✗${NC} $tool not found"
        return 1
    fi
}

echo "Core FPGA Tools:"
check_tool "yosys" "yosys --version"
check_tool "nextpnr-ecp5" "nextpnr-ecp5 --version"
check_tool "ecppack" "ecppack --help 2>&1 | head -n 1"
check_tool "ecpunpack" ""

echo ""
echo "VHDL Tools:"
check_tool "ghdl" "ghdl --version | head -n 1"

echo ""
echo "Programming Tools:"
check_tool "openFPGALoader" "openFPGALoader --help 2>&1 | grep -i version | head -n 1"

echo ""
echo "Build Tools:"
check_tool "cmake" "cmake --version | head -n 1"
check_tool "make" "make --version | head -n 1"

echo ""
echo "========================================="
echo "Yosys Plugin Check:"
echo "========================================="
if yosys -p "help ghdl" 2>&1 | grep -q "ghdl"; then
    echo -e "${GREEN}✓${NC} GHDL plugin available in Yosys"
else
    echo -e "${YELLOW}!${NC} GHDL plugin not found in Yosys"
    echo "  Will use ghdl synth instead"
fi

echo ""
echo "========================================="
echo "Summary:"
echo "========================================="

MISSING=""
command -v yosys &> /dev/null || MISSING="${MISSING}yosys "
command -v nextpnr-ecp5 &> /dev/null || MISSING="${MISSING}nextpnr-ecp5 "
command -v ecppack &> /dev/null || MISSING="${MISSING}ecppack "
command -v ghdl &> /dev/null || MISSING="${MISSING}ghdl "
command -v openFPGALoader &> /dev/null || MISSING="${MISSING}openFPGALoader "

if [ -z "$MISSING" ]; then
    echo -e "${GREEN}All essential tools found!${NC}"
else
    echo -e "${RED}Missing tools:${NC} $MISSING"
fi

echo ""
