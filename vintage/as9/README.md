# 6809_Bootstrap

**An opinionated framework for Motorola 6809 microprocessor development**

Build ROM images for your 6809 PCB projects on modern Apple Silicon and Linux systems. Everything you need is local, portable, and ready to go.

## What Is This?

6809_Bootstrap is a complete development environment for the Motorola 6809 microprocessor:

- **Write** 6809 assembly code on your modern Mac or Linux machine
- **Assemble** to machine code using the included AS9 cross-assembler
- **Generate** ROM-ready S19 files for programming your EPROM chips
- **No installation required** - everything is self-contained

## Quick Start

```bash
# Create a new project
make new PROJECT=my_first_rom

# Edit your code
vim src/my_first_rom/main.asm

# Build ROM image
make build PROJECT=my_first_rom

# Your ROM file is ready:
# → build/my_first_rom/main.s19
```

That's it! You now have a complete ROM image ready for your 6809 PCB.

---

## Directory Structure

```
6809_Bootstrap/
├── Makefile              - Main build system
├── README.md             - This file
│
├── lib/                  - Assembler toolchain (don't modify)
│   ├── as9               - AS9 cross-assembler binary (ARM64)
│   └── as9_source/       - C source code for AS9
│       └── Makefile      - Assembler build
│
├── src/                  - Your 6809 projects go here
│   └── <project>/
│       └── main.asm      - Your assembly code
│
├── examples/             - Ready-to-use example projects
│   ├── blinker.asm       - LED blinker (great first test!)
│   ├── hello.asm         - String/data handling
│   └── minimal.asm       - Bare bones template
│
├── templates/            - Project templates
│   └── minimal.asm       - Default new project template
│
├── build/                - Build outputs (generated)
│   └── <project>/
│       ├── main.asm      - Copy of source
│       ├── main.lst      - Listing with addresses + bytes
│       ├── main.s19      - S-record for ROM programmer ⭐
│       ├── main.bin      - Raw binary
│       ├── main.sym      - Symbol table
│       └── main.crf      - Cross-reference
│
└── doc/                  - Additional documentation
    ├── MODERNIZATION.md  - Technical details of assembler port
    ├── ABOUT_dSYM.md     - Debug symbols info
    └── as11v2.pdf        - Full 6809 instruction reference
```

---

## Workflow

### 1. Create a New Project

```bash
make new PROJECT=led_blinker
```

This creates:
- `src/led_blinker/main.asm` - Your assembly file (from template)
- Project is ready to edit and build

### 2. Write Your Code

Edit `src/led_blinker/main.asm`:

```assembly
; LED Blinker Example
        ORG     $C000           ; ROM starts here

START   LDS     #$0200          ; Set up stack
        LDA     #$01            ; Start value

LOOP    STA     $4000           ; Output to LED port
        BSR     DELAY           ; Wait
        EORA    #$01            ; Toggle bit
        BRA     LOOP            ; Repeat

DELAY   LDX     #$FFFF          ; Delay counter
DLOOP   LEAX    -1,X
        BNE     DLOOP
        RTS

; Reset vector (CPU jumps here on power-up)
        ORG     $FFFE
        FDB     START

        END
```

### 3. Build Your Project

```bash
make build PROJECT=led_blinker
```

All output formats are generated in one pass:
- `build/led_blinker/main.lst` - Listing with addresses and machine code
- `build/led_blinker/main.s19` - **S-record for ROM programmer** ⭐
- `build/led_blinker/main.bin` - Raw binary
- `build/led_blinker/main.sym` - Symbol table
- `build/led_blinker/main.crf` - Cross-reference

### 4. Program Your ROM

**Quick method (automated):**
```bash
make flash PROJECT=led_blinker
```

**Manual method:**
1. Open your ROM programmer software (TL866, MiniPro, etc.)
2. Load `build/led_blinker/main.s19` or `main_32k.bin` (see below)
3. Program your EPROM chip (27128, 28C256, etc.)
4. Install in your 6809 PCB
5. Power on and watch it run!

---

## ROM Programming for 28C256 with A14 Tied HIGH

If you're using a 28C256 EEPROM with pin 1 (A14) tied to +5V, you need a special 32KB ROM image.

### Quick Method

```bash
# Build + create 32KB ROM image
make rom PROJECT=myproject

# Build + flash to EEPROM (requires minipro)
make flash PROJECT=myproject
```

### How It Works

**Hardware Configuration:**
- EEPROM: 28C256 (32KB)
- Pin 1 (A14): Tied to +5V
- Effective size: 16KB (uses upper half of ROM)

**Address Mapping:**
```
CPU Address Range  →  ROM Physical Address
$C000 - $FFFF      →  $4000 - $7FFF (upper 16KB)
```

With A14 tied HIGH, the CPU always reads from the upper 16KB of the ROM chip. The `make rom` command automatically:
1. Parses your S19 file
2. Creates a 32KB image with your code in the upper half
3. Ensures the reset vector is at the correct location ($7FFE-$7FFF)
4. Outputs `build/<project>/main_32k.bin`

**Why This is Needed:**
- Normal assembly creates code for CPU addresses ($C000-$FFFF)
- A14 tied HIGH means ROM addresses must be in upper half ($4000-$7FFF)
- The conversion script maps CPU addresses to correct ROM addresses

**Manual Programming:**
```bash
# After running 'make rom PROJECT=myproject'
minipro -p AT28C256 -w build/myproject/main_32k.bin
```

**Files Generated:**
- `main.s19` - Standard S-record (may not work directly with A14 tied HIGH)
- `main_32k.bin` - 32KB ROM image for 28C256 ⭐ **Use this one!**

**Verification:**
The build system automatically verifies:
- Reset vector is at correct ROM location
- All interrupt vectors are properly mapped
- Code is in the upper 16KB as required

For more details, see the technical explanation in the ROM Programming section below.

---

## Build System Commands

### Create New Project

```bash
make new PROJECT=<project_name>
```

Creates a new project in `src/<project_name>/` with a minimal template.

### Build Project

```bash
# Build your project (uses src/<project>/main.asm)
make build PROJECT=<project_name>

# Build with specific output options
make build PROJECT=<project_name> OPTIONS="l s19"

# Build with different source file
make build PROJECT=<project_name> SOURCE=other.asm
```

### Build Examples

```bash
make example-blinker    # Build examples/blinker.asm
make example-hello      # Build examples/hello.asm
make example-minimal    # Build examples/minimal.asm
```

### Other Commands

```bash
make list               # List all projects in src/
make clean              # Clean all build outputs
make clean-project PROJECT=<name>  # Clean specific project
make assembler          # Rebuild AS9 from source
make help               # Show all commands
```

### Build Options

Control what output files are generated (space-separated):

| Option | Output | Description |
|--------|--------|-------------|
| `l` | `.lst` | Listing with addresses + machine code |
| `c` | (adds to `.lst`) | Include cycle counts in listing |
| `s` | `.sym` | Symbol table |
| `bin` | `.bin` | Raw binary file |
| `s19` | `.s19` | S-record for ROM programmer ⭐ |
| `cre` | `.crf` | Cross-reference |

**Default:** `l c s bin s19 cre` (generates everything)

---

## Understanding the Output

### The Listing File (.lst)

Shows your source code with addresses and machine code bytes:

```
Line# Addr  Bytes           Source
----- ----  --------------- ----------------------------------
0001  C000                  ORG     $C000
0002  C000  10 CE 02 00     LDS     #$0200    ; Set stack
0003  C004  86 01           LDA     #$01      ; Load A
0004  C006  B7 40 00        STA     $4000     ; Output to port
0005  C009  20 FB           BRA     $C006     ; Loop
```

- **Addr** - Memory address where this code goes
- **Bytes** - **The actual machine code** (what goes in ROM!)
- **Source** - Your assembly code

### The S19 File (.s19)

This is what you load into your ROM programmer:

```
S11EC00010CE02008601B740008D04880120F734108EFFFF301F26FC351039D3
S105FFFEC0003D
S9030000FC
```

**Motorola S-Record format:**
- Text-based, human-readable hex
- Includes addresses (tells programmer where each byte goes)
- Has checksums (error detection)
- Industry standard since the 1970s
- Compatible with most ROM programmer software

### What Actually Goes Into ROM?

The **bytes** shown in the listing are the machine code that goes into your ROM chip.

Example:
```
Assembly:  LDS #$0200
Bytes:     10 CE 02 00
Location:  $C000

When the 6809 reads address $C000:
  → Gets byte $10 (opcode for LDS)
  → Gets byte $CE (immediate mode)
  → Gets bytes $02 $00 (the value $0200)
  → Executes: Sets stack pointer to $0200
```

The bytes flow directly: **assembler → ROM chip → 6809 CPU**

---

## 6809 Programming Essentials

### Memory Map

Typical ROM layout for 6809 systems:

```
$0000-$00FF   Zero Page (fast direct addressing)
$0100-$01FF   Stack space
$0200-$7FFF   RAM (varies by system)
$8000-$BFFF   ROM or RAM
$C000-$FFEF   Your ROM code
$FFF0-$FFFF   Interrupt vectors ⭐
```

### Required: Reset Vector

**Your ROM must include a reset vector at $FFFE:**

```assembly
        ORG     $FFFE
        FDB     START           ; CPU jumps here on power-up
```

When the 6809 powers on, it reads address $FFFE (16-bit value) and jumps there. This is **mandatory** - without it, your ROM won't run.

### Common Instructions

**Load/Store:**
```assembly
LDA  #$42      ; Load A immediate
LDB  $10       ; Load B from memory
LDX  #$1000    ; Load X (16-bit)
STA  $4000     ; Store A to memory
STX  ,Y        ; Store X to address in Y
```

**Arithmetic:**
```assembly
INCA           ; Increment A
DECA           ; Decrement A
ADDA #$05      ; Add to A
SUBA #$01      ; Subtract from A
```

**Branches (short: ±126 bytes):**
```assembly
BRA  LABEL     ; Branch always
BEQ  LABEL     ; Branch if equal (Z=1)
BNE  LABEL     ; Branch if not equal
BLO  LABEL     ; Branch if lower (unsigned)
```

**Long Branches (16-bit: any distance):**
```assembly
LBRA LABEL     ; Long branch always
LBEQ LABEL     ; Long branch if equal
```

**Subroutines:**
```assembly
BSR  SUB       ; Branch to subroutine (short)
JSR  $C000     ; Jump to subroutine (any address)
RTS            ; Return from subroutine
```

**Stack Operations:**
```assembly
PSHS A,B,X,Y   ; Push to S stack
PULS A,B,X,Y   ; Pull from S stack
```

**Indexed Addressing (6809's specialty!):**
```assembly
LDA  ,X        ; Load from address in X
STA  ,Y+       ; Store to Y, then increment Y
LDB  5,X       ; Load from X+5
STA  [,X]      ; Indirect through X
```

**Full instruction set:** See [doc/as11v2.pdf](doc/as11v2.pdf)

### Assembler Directives

```assembly
        ORG  $C000      ; Set origin address

MAXVAL  EQU  $FF        ; Define constant

; Data definitions
        FCB  $12,$34    ; Form constant bytes
        FDB  $1234      ; Form double byte (16-bit word)
        FCC  "HELLO"    ; Form constant characters (string)

; Reserve memory
BUFFER  RMB  256        ; Reserve 256 bytes
ZEROS   ZMB  10         ; Reserve 10 bytes (cleared)

        END  START      ; End (optional entry point)
```

---

## Example Projects

### Start with Blinker

Perfect first test for your PCB:

```bash
make example-blinker
cat build/example_blinker/blinker.lst
```

Toggles an LED on bit 0 of I/O port $4000.

### Hello World Data

Shows string handling and data:

```bash
make example-hello
```

### Your Own Project

```bash
# Create project
make new PROJECT=my_project

# Edit it
vim src/my_project/main.asm

# Build it
make build PROJECT=my_project

# Check output
cat build/my_project/main.lst

# Program ROM with:
# → build/my_project/main.s19
```

---

## Troubleshooting

### "Branch out of Range"

Short branches (BRA, BEQ, etc.) are limited to ±126 bytes.

**Solution:** Use long branches:
```assembly
BRA  LABEL    ; ±126 bytes
LBRA LABEL    ; Any distance (adds 1 byte to instruction)
```

### "Phasing Error"

Label has different value in pass 1 vs pass 2. Usually caused by forward references in expressions that change size.

**Fix:** Use explicit addressing modes or reorganize code.

### "Unrecognized Mnemonic"

- Check instruction spelling
- Refer to [doc/as11v2.pdf](doc/as11v2.pdf) for full instruction list

---

## Best Practices

### Code Organization

```assembly
; Good practice:
        ORG     $C000

; === Initialization ===
START   LDS     #$0200          ; Stack
        LDX     #$1000          ; I/O base
        ; ... setup ...

; === Main Program ===
MAIN    ; ... your code ...
        BRA     MAIN

; === Subroutines ===
DELAY   ; ...
        RTS

; === Data ===
MSG     FCC     "HELLO"

; === Vectors ===
        ORG     $FFFE
        FDB     START
```

### Tips

1. **Start with blinker** - Test that your ROM/PCB works
2. **Use meaningful labels** - `MOTOR_ON` not `L1`
3. **Comment your code** - You'll thank yourself later
4. **Always include reset vector** - At $FFFE
5. **Set up stack first** - `LDS #$0200` in your startup code

### Memory Efficiency

- Use zero page (direct) addressing when possible (faster, smaller)
- Short branches save 1 byte vs long branches
- Indexed addressing is powerful but can be slower

---

## Rebuilding the Assembler

The AS9 assembler binary is pre-built, but if you modify the C source:

```bash
cd lib/as9_source
make clean
make
```

This compiles the C source and outputs the binary to `lib/as9`.

**Requirements:**
- GCC or Clang
- Standard C library

---

## What is the 6809?

The **Motorola 6809** (1979) is an elegant 8-bit microprocessor known for:
- Clean, orthogonal instruction set
- Advanced indexed addressing modes
- Used in classic computers (TRS-80 Color Computer, Dragon, Vectrex)
- Still popular for homebrew retro projects

This framework lets you write programs for the 6809 on your modern Mac or Linux machine.

---

## What Was Modernized

The AS9 assembler (originally from 2004) has been updated:

- ✅ **Compiles on Apple Silicon (M3 Mac)**
- ✅ **K&R C → ANSI C** (~40 functions updated)
- ✅ **Added modern headers** (stdlib.h, ctype.h, etc.)
- ✅ **Fixed all compiler warnings**
- ✅ **Native ARM64 binary** (74KB)

**Technical details:** See [doc/MODERNIZATION.md](doc/MODERNIZATION.md)

---

## Additional Documentation

- **[doc/MODERNIZATION.md](doc/MODERNIZATION.md)** - Technical details of C code updates
- **[doc/as11v2.pdf](doc/as11v2.pdf)** - Complete 6809 assembler manual

---

## Technical Details: ROM Programming with A14 Tied HIGH

### The Problem

When using a 28C256 (32KB EEPROM) as a drop-in replacement for a 27C128 (16KB EPROM), pin 1 is often tied HIGH to make it act like a 16KB ROM. However, this creates an addressing issue:

**28C256 vs 27C128 Pinout:**
| Pin | 27C128 (16KB) | 28C256 (32KB) | Typical Config |
|-----|---------------|---------------|----------------|
| 1   | A14 / VCC     | A14           | +5V (HIGH)     |
| 26  | A13           | A13           | Connected      |
| 27  | VCC           | /WE           | +5V (HIGH)     |
| 28  | VCC           | VCC           | +5V            |

With pin 1 (A14) tied HIGH:
- A14 is always 1 → CPU only accesses upper 16KB of ROM
- ROM addresses $4000-$7FFF are accessible
- ROM addresses $0000-$3FFF are never accessed

### Address Translation

Your code is assembled for CPU addresses:
```
$C000 - $FFFF  (16KB range)
```

But the ROM chip with A14=1 maps this to:
```
$4000 - $7FFF  (upper 16KB of the 32KB chip)
```

**Translation formula:**
```
ROM_offset = CPU_address - $C000 + $4000
```

**Example - Reset Vector:**
- CPU address: `$FFFE` (where CPU reads reset vector)
- Calculation: `$FFFE - $C000 + $4000 = $7FFE`
- Result: Reset vector must be at ROM address `$7FFE-$7FFF`

### The Solution

The `tools/s19_to_32k.py` script:

1. **Creates blank 32KB image:**
   ```python
   rom_32k = bytearray([0xFF] * 32768)
   ```

2. **Parses S19 file for addresses:**
   ```
   S1 13 FFFE FFD4FFD8FFDCFFE0FFE4FFE8FFECF837 B5
          ^^^^
          CPU address $FFFE
   ```

3. **Maps to ROM offset:**
   ```python
   if addr >= 0xC000:
       rom_offset = addr - 0xC000 + 0x4000
       rom_32k[rom_offset:rom_offset + len(data)] = data
   ```

4. **Verifies vectors:**
   - Checks reset vector at ROM $7FFE-$7FFF
   - Shows all interrupt vectors for debugging

### Automated Build Process

The Makefile orchestrates this automatically:

```makefile
rom: build
    # 1. Assemble code → generates main.s19
    # 2. Run s19_to_32k.py → creates main_32k.bin
    # 3. Verify reset vector is correct

flash: rom
    # 1. Build ROM image
    # 2. Program with minipro
    # 3. Verify programming
```

### Why Not Just Program the S19 Directly?

Some ROM programmers can handle S19 files with address offsets, but:
- Not all programmers support this
- Minipro requires binary files
- Binary format guarantees exact ROM contents
- Easier to verify with hexdump

### Verification

After building, you can verify the ROM image:

```bash
# Check reset vector location
hexdump -C build/combined/main_32k.bin | grep "00007ff0"

# Expected output:
# 00007ff0  ff d4 ff d8 ff dc ff e0  ff e4 ff e8 ff ec f8 37
#                                                          ^^^^
#                                                    Reset vector $F837
```

### Alternative: Different Hardware Config

If you could change your hardware, alternatives include:
- Tie A14 LOW → use lower 16KB (offset $0000-$3FFF)
- Connect A14 to address decoder → switch between upper/lower 16KB
- Use actual 27C128 chip → no offset needed

But with A14 tied HIGH, the automated `make rom` / `make flash` workflow handles everything correctly.

---

## Credits

- **Original AS9 assembler:** Motorola (circa 1980s)
- **Linux port (2004):** [Albert van der Horst](https://home.hccnet.nl/a.w.m.van.der.horst/m6809.html) (HCC Forth gg)
- **Modern port & framework (2025):** Apple Silicon update + opinionated tooling

---

## License

Public domain (as per original AS9 license)

---

## Quick Reference

```bash
# Create project
make new PROJECT=<project_name>

# Build project
make build PROJECT=<project_name>

# Build + create 32KB ROM image (for 28C256 with A14 tied HIGH)
make rom PROJECT=<project_name>

# Build + flash to EEPROM (requires minipro)
make flash PROJECT=<project_name>

# Build example
make example-blinker

# List projects
make list

# View listing
cat build/<project>/main.lst

# ROM files
build/<project>/main.s19        # Standard S-record
build/<project>/main_32k.bin    # 32KB ROM for 28C256 with A14=HIGH

# Rebuild assembler
make assembler

# Clean builds
make clean
```
