# AT89S52 Development Board

Multi-function demo program for the Atmel AT89S52 microcontroller, compiled with SDCC and programmed using the T48 programmer via minipro.

## Hardware

- **Microcontroller**: AT89S52 (8051-compatible, 8KB Flash, 256B RAM, 40-pin DIP)
- **Crystal**: 11.0592 MHz (standard for UART applications)
- **Programmer**: T48 (Gecu) programmer
- **Serial Interface**: FT232 USB-to-TTL adapter

## Features

Current demo program includes:
- **P1.0**: Fast blinking LED (~1 kHz) - visible on scope
- **P1.1**: LED controlled by switch on P2.0 (toggle on button press)
- **P1.2**: Slow blinking LED (~1 Hz) - human visible
- **P2.0**: Switch input with edge detection
- **UART**: Serial communication at 9600 baud via P3.0/P3.1

## Requirements

```bash
brew install sdcc      # Small Device C Compiler
brew install minipro   # Programmer software
```

Hardware needed:
- T48 programmer with AT89S52 in socket
- FT232 USB-to-TTL adapter (for serial communication)
- 11.0592 MHz crystal with 22pF capacitors

## Circuit Wiring

### Minimal Working Configuration

```
Power:
  VCC (pin 40) ─── 5V
  GND (pin 20) ─── Ground

Clock (11.0592 MHz crystal - required for accurate UART):
  XTAL1 (pin 18) ─── Crystal ─── XTAL2 (pin 19)
  XTAL1 ─── [22pF] ─── GND
  XTAL2 ─── [22pF] ─── GND

Reset Circuit (Active-HIGH reset):
  RST (pin 9) ──┬─── [10kΩ] ─── GND
                ├─── [10µF Cap +] ─── VCC
                └─── [Switch] ─── VCC

  Normal operation: Switch open, RST pulled LOW
  Reset: Press switch to pull RST HIGH

Critical Pins:
  EA (pin 31) ─── VCC (MUST be HIGH for internal Flash execution)
  P2.6 (pin 27) ─── [10kΩ] ─── GND (prevent programming mode)
  P2.7 (pin 28) ─── [10kΩ] ─── GND (prevent programming mode)

Demo I/O:
  P1.0 (pin 1) ─── [220-330Ω] ─── LED1 anode ─── GND
  P1.1 (pin 2) ─── [220-330Ω] ─── LED2 anode ─── GND
  P1.2 (pin 3) ─── [220-330Ω] ─── LED3 anode ─── GND
  P2.0 (pin 21) ─── [Switch] ─── VCC
  P2.0 ─── [10kΩ] ─── GND (pull-down for switch)

UART (Serial Communication):
  P3.0 / RXD (pin 10) ─── FT232 TXD
  P3.1 / TXD (pin 11) ─── FT232 RXD
  GND ─── FT232 GND
```

## Building and Flashing

### Compile the program
```bash
make
```

Generates `blink.hex` (Intel HEX format, ~2KB with UART support)

### Flash to AT89S52
```bash
make flash
```

Or manually:
```bash
minipro -p AT89S52@DIP40 -w blink.hex
```

### Verify flash contents
```bash
make verify
```

### Read chip ID
```bash
minipro -p AT89S52@DIP40 -D
```

Expected Chip ID: `0x1E5206`

### Erase chip
```bash
make erase
```

## Serial Communication

Connect FT232 USB-to-TTL adapter and open serial terminal at **9600 baud, 8N1**:

```bash
screen /dev/cu.usbserial-* 9600
```

Expected output:
```
=============================
AT89S52 Demo Program
Clock: 11.0592 MHz
Baud: 9600
=============================
Status: P1.0=0 P1.1=1 P1.2=1 SW=LOW
Switch pressed!
Status: P1.0=1 P1.1=1 P1.2=0 SW=LOW
```

- Status updates every ~5 seconds
- "Switch pressed!" message when P2.0 button is pressed

## Project Files

- **blink.c** - Main source code with GPIO, UART, and switch handling
- **Makefile** - Build configuration for SDCC
- **blink.hex** - Compiled Intel HEX file (generated)
- **8051.h.md** - Reference documentation for 8051 registers
- **README.md** - This file

## Code Structure

The current program demonstrates:

1. **UART Communication**: Configured via Timer 1 for precise 9600 baud
2. **Multi-rate LED Blinking**: Software timing for different frequencies
3. **Switch Debouncing**: Edge detection for clean button presses
4. **Concurrent Tasks**: Main loop handles multiple I/O operations

## Important Notes

### Crystal Frequency
- **Use 11.0592 MHz** for accurate UART baud rates
- This frequency divides perfectly for standard baud rates (9600, 19200, 38400, etc.)
- Other crystals (like 12 MHz or 16 MHz) will cause UART timing errors

### Reset Behavior
- **Active-HIGH reset**: RST LOW = run, RST HIGH = reset
- Power-on reset handled by 10µF capacitor
- Manual reset via button

### Critical Pin Configuration
- **EA (pin 31)**: MUST be tied to VCC for internal Flash execution
- **P2.6/P2.7**: MUST be LOW during normal operation to prevent parallel programming mode
- **P0**: Open-drain port, requires external pull-ups if used as outputs

### UART Timing
With 11.0592 MHz crystal:
```
TH1 = 0xFD for 9600 baud (exact)
Baud = 11059200 / (384 × (256 - TH1))
     = 11059200 / (384 × 3) = 9600
```

## T48 Programmer

- Firmware: 00.1.34 (newer than expected 01.1.32)
- T48 support in minipro marked "not complete" but works perfectly for AT89S52
- Device code: 53A23371
- Supply voltage: ~5.08V

## Supported Packages

minipro supports AT89S52 in multiple packages:
- `AT89S52@DIP40` (used in this project)
- `AT89S52@PLCC44`
- `AT89S52@PQFP44`
- `AT89S52@TQFP44`

## Next Steps / Future Projects

- [ ] Design PCB breakout board in KiCad
- [ ] Add DAC interface (Burr-Brown DAC80 with ±12V supply)
- [ ] Implement I2C/SPI communication
- [ ] Add interrupt-driven timers for precise timing
- [ ] Create library of reusable modules (UART, delays, etc.)

## References

- AT89S52 Datasheet: [Microchip/Atmel AT89S52](https://www.microchip.com/en-us/product/AT89S52)
- SDCC Documentation: [sdcc.sourceforge.net](http://sdcc.sourceforge.net/)
- 8051 Register Reference: See `8051.h.md` in this directory
- minipro: [gitlab.com/DavidGriffith/minipro](https://gitlab.com/DavidGriffith/minipro)

## License

This is a personal development/learning project. Code is provided as-is for educational purposes.
