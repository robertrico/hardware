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

### Option A: ROM Development (Burn to EPROM)

Follow this workflow when creating ROM images to burn into EPROM chips.

### Option B: ASSIST09 Development (Serial Testing)

If you have a 6809 SBC running the ASSIST09 monitor ROM, you can develop and test code via serial connection without burning EPROMs. See the **[ASSIST09 Serial Development](#assist09-serial-development)** section below.

---

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

## ASSIST09 Serial Development

If your 6809 SBC is running the **ASSIST09 monitor ROM**, you can develop and test code without burning EPROMs. This workflow lets you write assembly on your laptop, then load it over serial for immediate testing.

### What is ASSIST09?

ASSIST09 is **not an assembler** - it's a **monitor ROM** that runs on your 6809 hardware and provides:
- Command-line interface via serial terminal
- Memory examination/modification commands
- Breakpoint debugging
- S-record loading via serial (plain text format)
- Program execution from RAM

The AS9 assembler in this repository runs on your modern laptop and generates S19 files that ASSIST09 can load.

### Serial Port Configuration

**IMPORTANT:** The ASSIST09 ROM in this repository ([src/assist09/assist09.asm](src/assist09/assist09.asm)) is configured for:

- **Baud Rate: 57,600 baud** (tested and working)
- **Data Format: 8-N-1** (8 data bits, no parity, 1 stop bit)
- **Control Register: $51** (÷16 divider)

This configuration works with a **3.6864 MHz clock** to the ACIA.

**To change the baud rate**, modify line 844 in [src/assist09/assist09.asm](src/assist09/assist09.asm):

```assembly
COON LDA #3 RESET ACIA CODE
 LDX <VECTAB+.ACIA LOAD ACIA ADDRESS
 STA ,X STORE INTO STATUS REGISTER
 LDA #$51 SET CONTROL (current value - 57,600 baud)
 STA ,X REGISTER UP
```

**Common baud rate values** (with 3.6864 MHz ACIA clock):

| Control Value | Divider | Calculated Baud | Actual Working Baud | Notes |
|---------------|---------|-----------------|---------------------|-------|
| `$15` | ÷1 | 3,686,400 | - | Too fast - not usable |
| `$51` | ÷16 | 230,400 | **57,600** | **Default in this ROM** ✓ |
| `$95` | ÷64 | 57,600 | - | Alternate configuration |

**Note:** The actual working baud rate of 57,600 with control value `$51` suggests there may be additional clock division in the hardware (likely ÷4 between oscillator and ACIA).

### Development Workflow

**1. Write Assembly on Your Laptop**

```bash
# Create a new project
make new PROJECT=test_program

# Edit your code
vim src/test_program/main.asm
```

**Important:** When writing code for ASSIST09, target RAM addresses (not ROM):

```assembly
; Example ASSIST09 program (runs from RAM)
        ORG     $0400           ; RAM address (adjust for your system)

START   LDS     #$0200          ; Set up stack
        LDA     #$01            ; Your code here
        STA     $4000           ; Output to port

LOOP    BRA     LOOP            ; Loop forever

        END     START
```

**2. Build Your Project**

```bash
# Build the S-record file
make build PROJECT=test_program

# Output: build/test_program/main.s19
```

**3. Connect to Your SBC**

```bash
# Using screen (recommended - allows easy exit)
screen /dev/ttyUSB0 57600

# Or using minicom
minicom -D /dev/ttyUSB0 -b 57600
```

You should see the ASSIST09 prompt:
```
ASSIST09
>
```

**4. Load Code Using `make load` (Recommended Method)**

This is the easiest and most reliable way to load code:

**In Terminal 1 (Connected to ASSIST09):**
```
> L         (press L and Enter to start Load command)
```

ASSIST09 will wait for the S-record transfer.

**In Terminal 2 (On Your Laptop):**
```bash
# Load the S19 file to ASSIST09
make load PROJECT=test_program SERIAL_PORT=/dev/ttyUSB0

# Press ENTER when prompted
# Watch as each S-record line is sent with proper timing
```

The `make load` command:
- Sends S-records character-by-character with 10ms delays
- Adds proper CR after each line
- Handles S9 (end) record correctly
- Prevents buffer overflow issues

**Alternative: Manual Methods**

If you can't use `make load`, these manual methods also work:

**Using the slow loader script:**
```bash
./load_slow.sh /dev/ttyUSB0 build/test_program/main.s19
```

**Using minicom (less reliable):**
1. Press `Ctrl-A`, then `Y` or `S` (Send file)
2. Select **"ascii"** protocol (NOT xmodem/ymodem/zmodem)
3. Navigate to `build/test_program/main.s19`
4. Press Enter to send

**Note:** Despite the README previously mentioning XMODEM, ASSIST09's `L` command expects **plain S-record text**, not XMODEM protocol packets. The character-by-character sending with delays in `make load` is what makes it reliable.

**5. Verify Load**

After transfer completes, ASSIST09 returns to the prompt. Verify your code loaded:

```
> M 0400         (Memory examine at $0400)
0400-10 CE 02 00...   (shows your assembled code)
```

**6. Execute Your Code**

```
> G 0400         (Go - execute at address $0400)
```

Your program starts running! To break execution:
- Press `Ctrl-X` or use a breakpoint
- Returns to ASSIST09 prompt

**7. Debug with ASSIST09 Commands**

```
> B 0410         (set Breakpoint at $0410)
> G 0400         (Go from start)
> R              (display Registers after break)
> T 10           (Trace 10 instructions)
> M 0400/        (Memory modify - change bytes)
```

### Quick ASSIST09 Command Reference

| Command | Description | Example |
|---------|-------------|---------|
| `L` | Load S-record via serial | `L` |
| `G <addr>` | Go - execute at address | `G 0400` |
| `M <addr>` | Memory examine/modify | `M 0400` |
| `R` | Display/modify registers | `R` |
| `B <addr>` | Set breakpoint | `B 0450` |
| `B -<addr>` | Delete breakpoint | `B -0450` |
| `B -` | Clear all breakpoints | `B -` |
| `T <count>` | Trace instructions | `T 20` |
| `D <addr>` | Display memory block | `D 0400` |

### Typical Development Loop

```bash
# Terminal 1: Connected to ASSIST09
screen /dev/ttyUSB0 57600

# Terminal 2: Edit and build
vim src/test_program/main.asm
make build PROJECT=test_program

# Terminal 1: In ASSIST09
> L                  # Start loader

# Terminal 2: Upload
make load PROJECT=test_program SERIAL_PORT=/dev/ttyUSB0
# (Press ENTER when prompted)

# Terminal 1: Execute and test
> G 0400             # Execute at $0400
> (Ctrl-X to break)
> R                  # Check registers
> M 0400             # Verify memory
```

Repeat this cycle for rapid iterative development without burning any ROMs!

### Memory Map for ASSIST09 Systems

Typical layout (verify with your specific hardware):

```
$0000-$00FF   Zero Page (fast direct addressing)
$0100-$01FF   Stack space
$0200-$7FFF   RAM (load your programs here)
$8000-$EFFF   RAM or empty
$F000-$FFFF   ASSIST09 ROM
```

**Always use RAM addresses** when writing code for ASSIST09 serial development. Use ROM addresses ($C000+) only when creating final ROM images.

### Troubleshooting

**"Load doesn't complete":**
- Use `make load` instead of manual methods - it handles timing correctly
- Check baud rate matches (**57,600 baud** for this ASSIST09 ROM)
- Verify S19 file exists: `ls build/your_project/main.s19`
- Ensure you pressed `L` in ASSIST09 before running `make load`
- Check serial port: `ls /dev/tty.* | grep usb`

**"make load says serial port not found":**
```bash
# Find your serial port
ls /dev/tty.* | grep -i usb

# Specify it explicitly
make load PROJECT=test_program SERIAL_PORT=/dev/tty.usbserial-1234
```

**"Code doesn't execute":**
- Check that ORG address matches G command address
- Verify RAM exists at the target address
- Use `M 0400` command to confirm code loaded correctly
- Ensure you're using RAM addresses ($0400-$7FFF), not ROM addresses

**"Breakpoints don't work":**
- RAM must be writable at breakpoint address
- ROM addresses can't have breakpoints
- Clear old breakpoints with `B -`

**"minicom ASCII upload doesn't work":**
- Don't use minicom's built-in upload - use `make load` instead
- `make load` sends data with proper character delays that ASSIST09 needs
- minicom's ASCII mode often sends too fast and causes buffer overflows

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

### Assembly and ROM Programming

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

### ASSIST09 Development Workflow

```bash
# 1. Create and build project
make new PROJECT=mytest
vim src/mytest/main.asm    # Use ORG $0400 for RAM
make build PROJECT=mytest

# 2. Terminal 1 - Connect to SBC
screen /dev/ttyUSB0 57600

# 3. Terminal 1 - In ASSIST09 monitor
> L                         # Load command

# 4. Terminal 2 - Upload S19 file
make load PROJECT=mytest SERIAL_PORT=/dev/ttyUSB0
# (Press ENTER when prompted)

# 5. Terminal 1 - Execute
> G 0400                    # Execute at $0400

# Common ASSIST09 commands
> M 0400                    # Memory examine
> R                         # Registers
> B 0450                    # Breakpoint
> T 10                      # Trace 10 instructions
> D 0400                    # Display memory
```
