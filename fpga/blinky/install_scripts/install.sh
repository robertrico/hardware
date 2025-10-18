#!/bin/sh

# List of packages to install
packages="
yosys
nextpnr
prjtrellis
ghdl
openfpgaloader
"

# Install each package individually
for package in $packages; do
    echo "Installing $package..."
    brew install "$package"
done