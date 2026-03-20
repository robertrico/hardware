# CoCo 3 Cross-Compilation Toolkit

Cross-compile C programs (with inline 6309 assembly) on macOS for the TRS-80 Color Computer 3, targeting both Disk BASIC and NitrOS-9. Deploys directly to a CoCoSDC via its SD card.

## Hardware Setup

- **CoCo 3** with HD63C09 (6309) CPU
- **CoCoSDC** — SD card-based storage device
  - SD card mounts on macOS at `/Volumes/COCO3`
  - NitrOS-9 HDD image: `HDD/63SDC.VHD`
  - Boot sequence: `Drive 0,"/hdd/63sdc"` then `DOS`

## Toolchain

| Tool | Purpose | Install |
|------|---------|---------|
| **CMOC** | C cross-compiler for 6809/6309 | `./setup.sh` |
| **lwtools** | Assembler (lwasm) and linker (lwlink) | `brew install lwtools` |
| **ToolShed** | Disk image tools (`decb`, `os9`) | `./setup.sh` |

All tools install to `~/.local/bin/`.

### First-Time Setup

```bash
brew install lwtools    # assembler/linker
./setup.sh              # builds and installs CMOC + ToolShed
```

CMOC is downloaded from the OVH mirror (the official site at `perso.b2b2c.ca` is intermittently down). ToolShed is built from the GitHub repo.

## Build Targets

All build commands require `PRGM=<name>` — there is no default.

### NitrOS-9 Programs (OS-9 executable format)

```bash
make PRGM=cshell               # build cshell from cshell.c
make deploy PRGM=cshell        # build + copy to CoCoSDC SD card
```

`make deploy` copies the binary into the `CMDS` directory of the NitrOS-9 VHD image on the mounted SD card. After ejecting and booting NitrOS-9, run the program by name.

### Disk BASIC Programs (LOADM/EXEC format)

```bash
make PRGM=smiley TARGET=decb       # compile for Disk BASIC
make dsk PRGM=smiley               # compile + wrap in a .dsk image
```

On the CoCo (before booting NitrOS-9):
```
Drive 0,"/smiley.dsk"
LOADM"SMILEY"
EXEC
```

## Development Workflow

```
 macOS                          CoCo 3
 ─────                          ──────
 edit foo.c
 make deploy PRGM=foo
 eject SD card ──────────────▶  insert SD card
                                boot NitrOS-9
                                run: foo
```

1. Write your `.c` file in the project directory
2. `make deploy PRGM=yourprogram` — compiles and injects into the VHD
3. Eject the SD card, move it to the CoCoSDC
4. Boot NitrOS-9 and run your program

## Programs

### cshell — Interactive Debug Shell (NitrOS-9)

An interactive command shell for memory inspection and system exploration.

**Commands:**

| Command | Description |
|---------|-------------|
| `help` | Show available commands |
| `dump ADDR [LEN]` | Hex dump memory at ADDR (hex), LEN bytes (decimal, default 64) |
| `peek ADDR` | Read single byte at hex address |
| `poke ADDR VAL` | Write byte VAL (hex) to address ADDR (hex) |
| `info` | Display system information |
| `cls` | Clear screen |
| `exit` / `quit` | Return to NitrOS-9 |

Addresses accept optional `$` prefix: `dump $FF00` or `dump FF00`.

### smiley — Semigraphics Demo (Disk BASIC)

Draws a smiley face using SG4 (Semigraphics-4) block characters with a 6309-accelerated screen clear via the `TFM` instruction. Press any key to return to BASIC.

## Writing New Programs

### NitrOS-9 (OS-9 target)

Create `myprog.c`:

```c
#include <cmoc.h>

int main(void)
{
    char *line;
    printf("Hello from CoCo 3!\n");

    /* 6309 inline assembly */
    asm {
        ldw     #$1234      ; 6309-only W register
        nop
    }

    printf("Press ENTER to exit.\n");
    line = readline();
    return 0;
}
```

Build and deploy:
```bash
make deploy PRGM=myprog        # OS-9 target (default)
make dsk PRGM=myprog           # Disk BASIC target (.dsk image)
```

### Disk BASIC target

Use `#include <coco.h>` (provides `byte`, `word`, VDG helpers) and compile with `--coco` flag. The binary is in LOADM format, runnable from Disk BASIC.

## CMOC Notes

- **C dialect**: Subset of C. Supports structs, pointers, arrays, `printf`, `sprintf`, string functions, `readline()`. No `malloc` under OS-9.
- **6309 instructions**: CMOC generates 6809 code. Use `asm { }` blocks for 6309-specific instructions (`TFM`, `LDW`, `STW`, `DECW`, `SEXW`, `BITMD`, etc.).
- **Variable references in asm**: Use `:varname` to reference C variables from inline assembly.
- **Types under OS-9**: `coco.h` is for Disk BASIC targets. For OS-9, use `cmoc.h` and define your own `typedef unsigned char byte;` if needed.
- **OS-9 I/O**: `printf()` and `readline()` work through OS-9 standard I/O (the terminal window).
- **Disk BASIC I/O**: Direct memory access to screen ($0400), PIA ($FF00/$FF02), etc.

## SG4 Reference (Semigraphics-4)

For Disk BASIC programs using the 32x16 text screen:

**Byte format**: `1CCCDDDD`
- `C` (3 bits): Color index
- `D` (4 bits): Quadrant enable — bit3=BL, bit2=BR, bit1=TL, bit0=TR

**Color table**:

| Value | Color |
|-------|-------|
| 0 | Green |
| 1 | Yellow |
| 2 | Blue |
| 3 | Red |
| 4 | Buff |
| 5 | Cyan |
| 6 | Magenta |
| 7 | Orange |

## Important Warnings

**Do NOT deploy programs with names that match existing NitrOS-9 commands.** The `CMDS` directory contains system binaries including `shell` (the command interpreter). Overwriting `shell` will make NitrOS-9 unbootable. Always use distinctive names (e.g., prefix with `c`) and check for collisions with:

```bash
os9 dir /Volumes/COCO3/HDD/63SDC.VHD,CMDS | tr -s ' ' '\n' | grep -i yourname
```

If `shell` is ever corrupted, restore from `shellplus`:
```bash
os9 copy /Volumes/COCO3/HDD/63SDC.VHD,CMDS/shellplus /Volumes/COCO3/HDD/63SDC.VHD,CMDS/shell -r
os9 attr /Volumes/COCO3/HDD/63SDC.VHD,CMDS/shell -epe
```

## Project Structure

```
coco3/
├── Makefile        # Build system — handles both targets + deployment
├── setup.sh        # One-time toolchain installer
├── cshell.c        # Interactive debug shell (NitrOS-9)
├── smiley.c        # SG4 graphics demo (Disk BASIC)
└── README.md
```
