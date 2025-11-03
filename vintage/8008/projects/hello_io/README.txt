================================================================================
PROJECT: Hello I/O for Intel 8008
================================================================================
STATUS: ✓ COMPLETED

Goal: Create an I/O-based system where the 8008 can output "Hello, World!"
      to a Mac terminal via simulation.

Acceptance Criteria:
✓ MUST use existing s8008.vhdl, rom_2kx8.vhdl, ram_1kx8.vhdl components
✓ Terminal on Mac displays "Hello, World!"
✓ Uses period-appropriate I/O port architecture (not UART)
✓ Demonstrates proper 8008 I/O timing and bus protocol

================================================================================
QUICK START
================================================================================

Build and run the project:
    cd projects/hello_io
    make all

This will:
1. Assemble hello_io.asm to machine code
2. Run the simulation
3. Display the console output: "Hello, World!"

Other targets:
    make asm          - Assemble program only
    make run          - Assemble and simulate
    make sim          - Simulate only (requires .mem file)
    make view-output  - Display console_output.txt
    make clean-proj   - Clean all generated files

================================================================================
PROJECT FILES
================================================================================

hello_io.asm            - 8008 assembly program that outputs "Hello, World!"
s8008_hello_io_tb.vhdl  - VHDL testbench with I/O console integration
Makefile                - Standalone build system
console_output.txt      - Console output file (generated)
hello_io.hex/.lst/.mem  - Assembled program files (generated)

Shared components (../../src/components/):
- io_console.vhdl       - I/O console peripheral (NEW)
- s8008.vhdl            - Intel 8008 CPU
- rom_2kx8.vhdl         - 2KB ROM
- ram_1kx8.vhdl         - 1KB RAM
- i8008_alu.vhdl        - ALU
- phase_clocks.vhdl     - Clock generator

================================================================================
ARCHITECTURE OVERVIEW
================================================================================

The Intel 8008 has dedicated I/O instructions that work differently from
memory access:
- OUT <port>: Writes accumulator (A) to I/O port 0-7 (3-bit address)
- IN <port>:  Reads from I/O port 0-7 into accumulator (A)

I/O Instruction Encoding (IMPORTANT):
The 8008 OUT instruction encoding is: OUT RRMMM where:
- RR = 2-bit register selector (00=A, 01=B, 10=C, 11=D)
- MMM = 3-bit port number (0-7)

Therefore:
- OUT from A to port 0 = 01 00000 1 = 0x41 (port address 8 in naken_asm)
- OUT from A to port 1 = 01 00001 1 = 0x49 (port address 9 in naken_asm)
- etc.

The io_console component decodes using port_out_addr(2 downto 0) to extract
the actual 3-bit port number from the 5-bit encoded address.

Memory Map:
- 0x0000 - 0x07FF (2KB): ROM
- 0x0800 - 0x0BFF (1KB): RAM

I/O Port Map:
- Port 0: Console TX Data (write only)
- Port 1: Console TX Status (read only, bit 0 = ready = always 1)
- Port 2: Console RX Data (read only, not implemented = 0x00)
- Port 3: Console RX Status (read only, not implemented = 0x00)

================================================================================
IMPLEMENTATION DETAILS
================================================================================

I/O Console Component (src/components/io_console.vhdl)
-------------------------------------------------------
A period-appropriate I/O console peripheral that:
- Accepts character output via OUT instruction to port 0
- Writes characters to console_output.txt using VHDL TEXTIO
- Reports characters to simulation console
- Implements edge detection to avoid duplicate captures
- Only flushes lines on newline characters (0x0A, 0x0D)

Testbench (s8008_hello_io_tb.vhdl)
-----------------------------------
Based on existing s8008 testbenches (s8008_search_tb.vhdl), adds:
- io_console component instantiation
- Connection to CPU port_out signals (port_out, port_out_addr, port_out_strobe)
- Uses local hello_io.mem file for ROM content

Assembly Program (hello_io.asm)
--------------------------------
Program flow:
1. JMP to MAIN at 0x0100
2. Initialize H:L register pair to 0x00C8 (string location in ROM)
3. Loop:
   - Load character from [H:L] into accumulator
   - Check for null terminator (0x00)
   - If null, jump to DONE
   - Output character via OUT 8 (port 0)
   - Increment L register
   - Jump back to loop
4. DONE: HLT

String data at 0x00C8: "Hello, World!\n\0"

================================================================================
TEST RESULTS
================================================================================

Simulation completed successfully:
- Instructions executed: 198
- Final CPU state: STOPPED (HLT instruction)
- Final PC: 0x0110
- Final H:L: 0x00D6 (one byte past null terminator)
- Console output: "Hello, World!\n"

Output file (console_output.txt):
    Hello, World!

Hex dump:
    00000000  48 65 6c 6c 6f 2c 20 57  6f 72 6c 64 21 0a 0a
              H  e  l  l  o  ,     W   o  r  l  d  !  \n \n

================================================================================
IMPLEMENTATION CHALLENGES & SOLUTIONS
================================================================================

Challenge 1: OUT Instruction Port Encoding
-------------------------------------------
Problem: naken_asm expects port numbers 8-15 for OUT from register A, not 0-7.
Solution: The 8008 encodes both source register and port in a 5-bit field.
         OUT from A to port 0 uses assembler port 8 (RR=00, MMM=000 = 01000).
         The io_console decodes using port_out_addr(2 downto 0) to extract
         the actual 3-bit port number.

Challenge 2: Double Character Output
------------------------------------
Problem: Each character appeared twice in console output.
Solution: Added edge detection using last_strobe variable to only capture
         on rising edge of port_out_strobe signal.

Challenge 3: Newline After Every Character
-------------------------------------------
Problem: File output had newline after every character due to writeline() call.
Solution: Only call writeline() when encountering actual newline characters
         (0x0A or 0x0D). For other characters, use write() only.

Challenge 4: Assembly Syntax
-----------------------------
Problem: naken_asm doesn't support .byte directive.
Solution: Used .dc8 (declare constant 8-bit) for individual bytes.

================================================================================
FUTURE ENHANCEMENTS
================================================================================

1. Input Support (Port 2/3)
   - Read characters from file or stdin
   - Simple echo program
   - Basic monitor/debugger

2. Additional I/O Ports
   - Port 4-7 for other peripherals
   - LED outputs
   - Switch inputs

3. Interactive Terminal
   - Use GHDL VPI to connect to actual terminal
   - Real-time bidirectional communication
   - More realistic testing

4. FPGA Implementation
   - Synthesize I/O console for FPGA
   - Connect to real UART on FPGA board
   - Replace VHDL 8008 with physical 8008 chip

================================================================================
REFERENCE: 8008 I/O INSTRUCTION OPCODES
================================================================================

OUT <port> - Output accumulator to port
  OUT 8  (port 0): 0x41  - OUT from A to port 0
  OUT 9  (port 1): 0x49  - OUT from A to port 1
  OUT 10 (port 2): 0x51  - OUT from A to port 2
  OUT 11 (port 3): 0x59  - OUT from A to port 3
  OUT 12 (port 4): 0x61  - OUT from A to port 4
  OUT 13 (port 5): 0x69  - OUT from A to port 5
  OUT 14 (port 6): 0x71  - OUT from A to port 6
  OUT 15 (port 7): 0x79  - OUT from A to port 7

IN <port> - Input from port to accumulator
  IN 0  (port 0): 0x40
  IN 1  (port 1): 0x48
  IN 2  (port 2): 0x50
  IN 3  (port 3): 0x58
  IN 4  (port 4): 0x60
  IN 5  (port 5): 0x68
  IN 6  (port 6): 0x70
  IN 7  (port 7): 0x78

Note: For OUT, naken_asm port numbers are 8-15 (not 0-7) because the
instruction encodes the source register in the upper 2 bits.

================================================================================
BUILD SYSTEM
================================================================================

The project uses a standalone Makefile that:
1. Includes ../../common.mk for standard GHDL/simulation rules
2. Defines RTL_SOURCES with absolute paths to avoid path issues
3. Overrides paths after common.mk inclusion
4. Provides project-specific targets for assembly and output viewing

Key Makefile variables:
- PROJECT_ROOT = ../..
- RTL_SOURCES = Full paths to all VHDL components
- TB_SOURCES = Local testbench file
- NAKEN_ASM = Path to naken_asm assembler

Dependencies:
- GHDL (VHDL simulator)
- naken_asm (8008 assembler)
- Python 3 (for hex to mem conversion)
- Make

================================================================================
SUCCESS CRITERIA - ALL MET ✓
================================================================================

✓ Uses existing s8008.vhdl CPU implementation
✓ Uses existing rom_2kx8.vhdl ROM component
✓ Uses existing ram_1kx8.vhdl RAM component
✓ Terminal displays "Hello, World!" via simulation
✓ Period-appropriate I/O port architecture (not UART)
✓ Demonstrates proper 8008 I/O timing via port_out_strobe
✓ Standalone project structure in projects/hello_io/
✓ Complete documentation and build system

================================================================================
END OF README
================================================================================
