#!/bin/bash
# Setup script for CoCo 3 cross-compilation toolchain on macOS
# Installs: CMOC (C compiler for 6809/6309) and ToolShed (decb disk utility)
#
# Prerequisites: lwtools (already installed via brew)

set -e

INSTALL_PREFIX="$HOME/.local"
BUILD_DIR="/tmp/coco3-toolchain-build"
mkdir -p "$BUILD_DIR" "$INSTALL_PREFIX/bin"

echo "=== CoCo 3 Cross-Compilation Toolchain Setup ==="
echo "Install prefix: $INSTALL_PREFIX"
echo ""

# Check for lwtools
if ! command -v lwasm &> /dev/null; then
    echo "ERROR: lwasm not found. Install lwtools first: brew install lwtools"
    exit 1
fi
echo "✓ lwtools found: $(lwasm --version 2>&1 | head -1)"

# --- Install CMOC ---
if command -v cmoc &> /dev/null; then
    echo "✓ cmoc already installed: $(cmoc --version 2>&1 | head -1)"
else
    echo ""
    echo "--- Installing CMOC (C compiler for 6809/6309) ---"
    cd "$BUILD_DIR"
    CMOC_VER="0.1.98"
    CMOC_TAR="cmoc-${CMOC_VER}.tar.gz"
    if [ ! -f "$CMOC_TAR" ]; then
        echo "Downloading CMOC ${CMOC_VER}..."
        # Primary: OVH mirror (official site perso.b2b2c.ca is currently down)
        curl -LO "http://gvlsywt.cluster051.hosting.ovh.net/dev/${CMOC_TAR}" || \
        curl -LO "http://perso.b2b2c.ca/~sarrazip/dev/${CMOC_TAR}"
    fi
    tar xzf "$CMOC_TAR"
    cd "cmoc-${CMOC_VER}"
    ./configure --prefix="$INSTALL_PREFIX"
    make -j$(sysctl -n hw.ncpu)
    make install
    echo "✓ CMOC installed to $INSTALL_PREFIX/bin/cmoc"
fi

# --- Install ToolShed (decb) ---
if command -v decb &> /dev/null; then
    echo "✓ decb already installed"
else
    echo ""
    echo "--- Installing ToolShed (decb disk image tool) ---"
    cd "$BUILD_DIR"
    if [ ! -d "toolshed" ]; then
        git clone https://github.com/n6il/toolshed.git
    fi
    cd toolshed
    # Build just decb (the disk BASIC utility we need)
    cd build/unix
    make -j$(sysctl -n hw.ncpu)
    cp ../../build/unix/decb/decb "$INSTALL_PREFIX/bin/"
    echo "✓ decb installed to $INSTALL_PREFIX/bin/decb"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Make sure $INSTALL_PREFIX/bin is in your PATH:"
echo "  export PATH=\"$INSTALL_PREFIX/bin:\$PATH\""
echo ""
echo "Then build the smiley demo:"
echo "  cd $(dirname "$0")"
echo "  make        # builds smiley.bin"
echo "  make dsk    # creates smiley.dsk for CoCoSDC"
