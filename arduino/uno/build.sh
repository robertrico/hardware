#!/bin/bash

# AVR Arduino Uno Build Script

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building AVR Arduino Uno project...${NC}"

# Create build directory if it doesn't exist
if [ ! -d "build" ]; then
    echo -e "${YELLOW}Creating build directory...${NC}"
    mkdir build
fi

# Navigate to build directory
cd build

# Configure CMake
echo -e "${YELLOW}Configuring CMake...${NC}"
cmake ..

# Build the project
echo -e "${YELLOW}Building project...${NC}"
cmake --build .

echo -e "${GREEN}Build complete!${NC}"
echo -e "${YELLOW}Generated files:${NC}"
ls -lh avr_uno_blink.elf avr_uno_blink.hex 2>/dev/null || echo "Files not found"

cd ..
