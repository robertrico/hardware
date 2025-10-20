# SBC09 - 6809 Simulator and Development Environment

A complete 6809 CPU emulator, assembler, and development environment. Originally written in 1994-1995 by L.C. Benschop, modernized for current systems.

## Features

- **v09** - Full 6809 CPU simulator/emulator
- **a09** - 6809 assembler
- **Forth system** - Complete Forth implementation with TETRIS game
- **Monitor ROM** - Machine language monitor and basic OS
- **XMODEM support** - File transfer protocol built-in
- **Example programs** - Including a BASIC interpreter

## Quick Start

```bash
# Build everything
make

# Run the emulator
./v09

# At the . prompt, start Forth
G8000

# Load TETRIS (after typing XLOAD in Forth)
# Press Ctrl-], then type: Usrc/forth/tetris.4
# Press Enter, then type: TT
```

See [QUICKSTART.md](QUICKSTART.md) for detailed instructions.

## Building

### Prerequisites

- GCC or compatible C compiler
- Make
- Unix-like environment (Linux, macOS, BSD)

### Build Commands

```bash
make              # Build everything (default)
make v09          # Build only emulator
make a09          # Build only assembler
make clean        # Remove build artifacts
make help         # Show all targets
```

## Project Structure

```
sbc09/
├── lib/              # Library source code
│   ├── emulator/     # v09 emulator (v09.c, engine.c, io.c)
│   ├── assembler/    # a09 assembler (a09.c)
│   ├── monitor/      # Monitor ROM assembly source
│   └── makerom.c     # ROM building utility
├── src/              # Source programs
│   ├── programs/     # YOUR 6809 programs (write here!)
│   ├── examples/     # Example programs included with SBC09
│   ├── forth/        # Forth system and TETRIS
│   └── basic/        # BASIC interpreter
├── build/            # Build artifacts (auto-generated)
│   ├── programs/     # Your built programs
│   ├── examples/     # Built example programs
│   └── monitor.s     # Assembled monitor
├── docs/             # Documentation
├── v09               # Emulator executable
├── a09               # Assembler executable
└── v09.rom           # Monitor ROM (with Forth)
```

## Usage

### Running the Emulator

```bash
./v09                 # Start emulator
./v09 -t trace.log    # Run with instruction trace
./v09 -e 0x1c         # Change escape character
```

**Controls:**
- Press **Ctrl-]** to access the `v09>` prompt (file operations)
- Press **Ctrl-]** again or just Enter to return to emulator

### Monitor Commands

At the `.` prompt:

- `G`_addr_ - Go/execute at address (e.g., `G8000` starts Forth)
- `M`_addr_ - Display memory
- `D`_addr_ - Disassemble code
- `B`_addr_ - Set/clear breakpoint
- `XL`_addr_ - Load via XMODEM
- `XS`_addr_,_len_ - Save via XMODEM

### Assembling Programs

```bash
./a09 -l output.lst -o output.bin source.asm
```

Options:
- `-l filename` - Generate listing file
- `-o filename` - Output binary file
- `-s filename` - Output S-record file

### v09> File Operations

At the `v09>` prompt (accessed via Ctrl-]):

- `U`_filename_ - Upload file to 6809 via XMODEM
- `D`_filename_ - Download from 6809 via XMODEM
- `S`_filename_ - Send file contents as keystrokes
- `L`_filename_ - Log output to file
- _Enter_ - Return to emulator

## Memory Map

```
$0000-$00FF   Zero page (monitor variables + user)
$0100-$03FF   Buffers and system stack
$0400-$7FFF   User RAM
$8000-$DFFF   User ROM space
$E000-$E1FF   I/O addresses (ACIA at $E000)
$E400-$FFFF   Monitor ROM
```

## Playing TETRIS

1. Start v09: `./v09`
2. Start Forth: `G8000` (at `.` prompt)
3. Prepare XMODEM: Type `XLOAD` in Forth
4. Press **Ctrl-]** to get `v09>` prompt
5. Upload: Type `Usrc/forth/tetris.4`
6. Return: Press Enter
7. Play: Type `TT` in Forth

**Controls:** J=left, K=rotate, L=right, Space=drop, P=pause, Q=quit

## Example Programs

Located in `src/examples/`:

- `test09.asm` - CPU instruction test
- `bench09.asm` - Performance benchmark
- `bin2dec.asm` - Binary to decimal converter
- `asmtest.asm` - Assembler feature test

Build with: `make examples`

## Development

### Writing Your Own Programs

Place your `.asm` files in `src/programs/`.

Example:
```bash
# Create your program
vim src/programs/myprogram.asm

# Build it (easy way!)
make program PROJECT=myprogram

# The makefile will show you how to run it:
./v09
# At . prompt: XL400
# At v09> prompt: Ubuild/programs/myprogram
# At . prompt: G400
```

### Modifying the Emulator

Source files in `lib/emulator/`:
- `v09.c` - Main emulator loop and command processing
- `engine.c` - 6809 CPU instruction execution
- `io.c` - Terminal and XMODEM I/O
- `v09.h` - Shared definitions

After modifications:
```bash
make clean
make v09
```

## Technical Details

### Special Instructions

- `SWI2` - Write character from register B to stdout
- `SWI3` - Read character to register B (sets carry on EOF)
- `CWAI`/`SYNC` - Stop simulator

### ACIA Emulation

Simulated 6850 ACIA at address `$E000`:
- Status/Control register: `$E000`
- Data register: `$E001`

## License

GNU General Public License v2.0

Copyright 1994-1995 L.C. Benschop
Modernization 2025

See [docs/COPYING](docs/COPYING) for full license text.

## Credits

- **Original Author:** L.C. Benschop (1994-1995)
- **6809 Architecture:** Motorola
- **TETRIS:** Dirk Uwe Zoller (Forth implementation)
- **Modernization:** 2025 updates for current compilers

## Contributing

This is a historical preservation project. Feel free to:
- Report bugs
- Improve documentation
- Add example programs
- Port to other platforms

## Resources

- [Original Documentation](docs/README.doc)
- [LaTeX Manual](docs/sbc09.tex)
- [Monitor Source](lib/monitor/monitor.asm)
- [Forth System](src/forth/)

## References

- 6809 Assembly Language Programming by Lance Leventhal
- Motorola 6809 Datasheet
- Forth-83 Standard

---

**Perfect for learning 6809 assembly while waiting for your hardware to arrive!** 🎮
