# SBC09 - 6809 Emulator Quick Start Guide

## What You've Got

This is a fully working **6809 CPU simulator/emulator** with:
- **v09** - The 6809 emulator
- **a09** - A 6809 assembler
- **v09.rom** - Monitor ROM (currently loaded with Forth + TETRIS!)
- Example programs and a BASIC interpreter

## Building

The project now has a modern build system:

```bash
make              # Build everything
make clean        # Remove build artifacts
make help         # Show all available targets
```

## Running the Emulator

### Start the emulator:
```bash
./v09
```

You'll see:
```
Welcome to BUGGY version 1.0
.
```

The `.` is the monitor prompt. You can now enter monitor commands.

### Exit the emulator:
Press **Ctrl-]** (Control and right bracket)

## Project Structure

```
sbc09/
├── lib/              # Library source code
│   ├── emulator/     # v09 emulator source
│   ├── assembler/    # a09 assembler source
│   └── monitor/      # Monitor ROM source
├── src/              # User programs
│   ├── forth/        # Forth system and TETRIS
│   ├── examples/     # Example 6809 programs
│   └── basic/        # BASIC interpreter
├── build/            # Build artifacts (auto-generated)
├── docs/             # Documentation
└── [executables]     # v09, a09, makerom
```

## Playing TETRIS in Forth!

**Important:** The ROM includes Forth, but TETRIS needs to be loaded via XMODEM transfer. Here's how:

### Method 1: Using XMODEM to Load TETRIS

**Important:** The `v09>` prompt requires special commands!

1. Start the emulator: `./v09`
2. At the `.` prompt, type: `G8000` (starts Forth)
   - You'll see "Welcome to Forth" and a blank line
   - **The cursor is waiting** - there's no visible prompt, just start typing!
3. Type `XLOAD` and press Enter (tells Forth to prepare for XMODEM receive)
4. Press **Ctrl-]** to get the special `v09>` prompt
5. At the `v09>` prompt, type: **`Usrc/forth/tetris.4`** (note the capital U!)
   - `U` means "Upload to 6809 via XMODEM"
   - You'll see blocks being transmitted
6. When transfer completes, just press Enter at the `v09>` prompt
7. You're back in Forth - type `TT` and press Enter to run TETRIS!

**v09> Commands:**
- `U<file>` - Upload file to 6809 via XMODEM
- `D<file>` - Download from 6809 via XMODEM
- `S<file>` - Send file contents as keystrokes
- `L<file>` - Log output to file
- Just press Enter to return to emulator

### Method 2: Create a Simple Test (Easier!)

Instead of loading TETRIS, try these simple Forth commands first:

```
./v09
G8000
```

After "Welcome to Forth", try these (press Enter after each):
- `1 2 + .` → Should print `3 OK`
- `10 20 * .` → Should print `200 OK`
- `." Hello 6809!" CR` → Should print `Hello 6809! OK`

### Game Controls (once TETRIS loads):
- `J` = Move left
- `L` = Move right
- `K` = Rotate
- `Space` = Drop piece
- `P` = Pause
- `Q` = Quit game

**Note:** Forth shows `OK` **after** each successful command, not as a prompt!

## Monitor Commands

At the `.` prompt you can:
- **G**_addr_ - Go/execute at address (e.g., `G8000` for Forth)
- **M**_addr_ - Display memory
- **D**_addr_ - Disassemble code
- **L** - Load program via XMODEM
- **S** - Save program via XMODEM

## Assembling Code

Assemble 6809 assembly files:
```bash
./a09 -l output.lst -o output.bin source.asm
```

Example programs included:
- [src/examples/test09.asm](src/examples/test09.asm) - Test program
- [src/examples/bench09.asm](src/examples/bench09.asm) - Benchmark
- [src/basic/basic.asm](src/basic/basic.asm) - BASIC interpreter
- [lib/monitor/monitor.asm](lib/monitor/monitor.asm) - The monitor itself

## ROM Files

Two ROM files are available:
- **v09.rom** - Currently contains the monitor + Forth
- **alt09.rom** - Backup with monitor + Forth + TETRIS loader

To switch ROMs:
```bash
cp alt09.rom v09.rom  # Use the Forth/TETRIS ROM
cp v09.rom.backup v09.rom  # Restore original monitor
```

## Learning 6809 Assembly

Perfect timing to learn while waiting for your PCB! The included files are great examples:
- Study [monitor.asm](monitor.asm) for a complete working OS
- Look at [test09.asm](test09.asm) for instruction examples
- Check [basic.asm](basic.asm) to see a complex interpreter

## Useful Options

Run v09 with tracing (for debugging):
```bash
./v09 -t trace.log
```

Specify trace address range:
```bash
./v09 -t trace.log -tl 0x8000 -th 0x9000
```

Change escape character:
```bash
./v09 -e 0x1c  # Use Ctrl-\\ instead of Ctrl-]
```

## Documentation

The project includes LaTeX documentation:
- [sbc09.tex](sbc09.tex) - Main documentation
- [monitor.tex](monitor.tex) - Monitor documentation

## Memory Map

- `$0000-$00FF` - Zero page (monitor variables + user)
- `$0100-$03FF` - Buffers and system stack
- `$0400-$7FFF` - User RAM
- `$8000-$DFFF` - User ROM space
- `$E000-$E1FF` - I/O addresses (ACIA at $E000)
- `$E400-$FFFF` - Monitor ROM

## Next Steps

1. Try running the emulator and exploring the monitor
2. Assemble one of the example programs
3. Write a simple "Hello World" in 6809 assembly
4. When your PCB arrives, you can test your code here first!

Enjoy your 6809 emulator!
