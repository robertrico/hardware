# FPGA Blinky - ECP5-5G Versa Development Kit

A simple LED blinker project for the Lattice ECP5-5G Versa Development Kit (LFE5UM5G-45F-VERSA-EVN).

## Hardware

**Board:** Lattice ECP5-5G Versa Development Kit
**Device:** LFE5UM5G-45F-8BG381C
**Package:** 381-ball caBGA
**FPGA:** ECP5-5G (45k LUTs, SERDES capable)

### Key Features Used
- 100 MHz LVDS oscillator (general purpose clock)
- 8x General Purpose LEDs (active low)
- 8x DIP switches
- PROGRAMN reset button

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
blinky/
├── Makefile              # Build system
├── README.md             # This file
├── constraints/
│   └── versa_ecp5.lpf    # Pin constraints for ECP5 Versa board
├── src/
│   └── blink.vhdl        # RTL source code
├── sim/
│   ├── test.vhdl         # Testbench
│   └── output.txt        # Simulation output
├── build/                # Generated build artifacts
└── work/                 # GHDL work directory
```

## Quick Start

### 1. Verify Toolchain
```bash
make check-tools
```

### 2. Simulate
Run the GHDL testbench to verify functionality:
```bash
make run                  # Interactive simulation (output to terminal)
make simulate             # Save output to sim/output.txt
make view                 # View saved simulation output
```

### 3. Synthesize
Build the FPGA bitstream:
```bash
make fpga                 # Full build: synth + pnr + bitstream
```

Or step by step:
```bash
make synth               # Synthesis only
make pnr                 # Place and route
make bitstream           # Generate .bit file
```

### 4. Program the FPGA

**Connect the board:**
- Connect 12V power adapter
- Connect USB cable (for programming)
- Set configuration DIP switches (SW4) to Master SPI mode: `010` (SW4.3=Down, SW4.2=Up, SW4.1=Down)

**Program SRAM (volatile - for testing):**
```bash
make program-sram        # Fast, lost on power cycle
```

**Program Flash (persistent):**
```bash
make program             # Survives power cycles
```

## Design Details

### RTL (`src/blink.vhdl`)
- **Clock:** 100 MHz LVDS from onboard oscillator
- **Blink Rate:** Configurable via generic (default: 1 Hz)
- **Counter:** Automatically sized based on clock frequency
- **Reset:** Synchronous, active high

### Simulation (`sim/test.vhdl`)
- Uses accelerated clock for fast simulation (1 kHz instead of 12 MHz)
- Tests multiple blink cycles
- Monitors LED state changes

### Constraints (`constraints/versa_ecp5.lpf`)
- Clock: Pin P3 (100 MHz LVDS)
- Reset: Pin W3 (PROGRAMN button)
- LED: Pin E16 (LED0, yellow, active low)

## Makefile Targets

### Simulation
```bash
make analyze-rtl         # Analyze RTL sources only
make analyze-tb          # Analyze RTL + testbench
make elaborate           # Build testbench executable
make run                 # Run simulation (terminal output)
make simulate            # Run simulation (save to file)
make view                # View saved output
```

### FPGA Build
```bash
make fpga                # Complete build
make synth               # VHDL → JSON netlist
make pnr                 # Place and route
make bitstream           # Generate .bit file
make program             # Program flash (persistent)
make program-sram        # Program SRAM (volatile)
```

### Utilities
```bash
make check-tools         # Verify toolchain installation
make clean               # Clean simulation files
make clean-all           # Clean everything
make help                # Show all targets
```

## Customization

### Change Blink Rate
Edit `src/blink.vhdl`:
```vhdl
generic (
    CLK_FREQ : integer := 100000000;  -- 100 MHz clock
    BLINK_FREQ : integer := 2          -- 2 Hz blink rate (was 1 Hz)
);
```

### Use Different LED
Edit `constraints/versa_ecp5.lpf`:
```lpf
# Change from LED0 (E16) to LED4 (F17)
LOCATE COMP "led" SITE "F17";
```

### Change FPGA Device Size
Edit `Makefile` if using different board variant:
```makefile
FPGA_DEVICE = 85k        # For LFE5UM5G-85F variant
```

## Board Configuration

### DIP Switch SW4 (Configuration Mode)
For normal operation, set to **Master SPI** mode:
- SW4.3: **Down** (CFG2 = 0)
- SW4.2: **Up** (CFG1 = 1)
- SW4.3: **Down** (CFG0 = 0)

### Status LEDs
- **D20 (Green):** DONE - Lights when configuration successful
- **D17 (Red):** INITN - Configuration error indicator
- **D19 (Red):** PROGRAMN indicator
- **D18 (Red):** GSRN indicator

### Programming
The board can be programmed via:
1. **USB** (J2) - Primary method, uses onboard FTDI chip
2. **JTAG** (J3) - Alternative, requires external programmer

## Troubleshooting

### "command not found" errors
- Ensure OSS CAD Suite is installed and in PATH
- Run: `make check-tools` to verify

### Programming fails
- Check USB connection
- Verify SW4 is set to Master SPI mode (010)
- Check 12V power is connected
- Try: `openFPGALoader -b versa_ecp5 --detect`

### LED doesn't blink
- LEDs are **active low** - design drives '0' to illuminate
- Check D20 (DONE) LED is lit (green)
- Verify power connections
- Try programming SRAM first: `make program-sram`

### Simulation shows no output
- Check `sim/output.txt` was created
- Try: `make run` for interactive output
- Verify GHDL is working: `ghdl --version`

## Hardware Resources

- [ECP5-5G Versa Board User Guide](docs/FPGA-EB-02048-1-4-ECP5-5G-Versa-Development-Kit-User-Guide.pdf)
- [ECP5-5G Family Datasheet](https://www.latticesemi.com/products/fpgaprogrammabledevices/ecp5)
- [Board Schematics](docs/) - See Appendix A of user guide

## Pin Reference (Quick)

| Signal | Pin  | Bank | I/O Type  | Note                    |
|--------|------|------|-----------|-------------------------|
| clk    | P3   | 6    | LVDS      | 100 MHz oscillator      |
| rst    | W3   | 8    | LVCMOS33  | PROGRAMN button         |
| led    | E16  | 2    | LVCMOS25  | LED0 (yellow, active-L) |

See `constraints/versa_ecp5.lpf` for complete pin assignments.

## License

This is a simple example project for learning FPGA development with open-source tools.

## References

- GHDL: https://github.com/ghdl/ghdl
- Yosys: https://github.com/YosysHQ/yosys
- nextpnr: https://github.com/YosysHQ/nextpnr
- openFPGALoader: https://github.com/trabucayre/openFPGALoader
- OSS CAD Suite: https://github.com/YosysHQ/oss-cad-suite-build
