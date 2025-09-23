# 6809 ROM Programs

This directory contains 6809 assembly programs designed to run from ROM on the 6809 processor being monitored by the Raspberry Pi Pico W serial monitor.

## reset_loop.s

A minimal 6809 assembly program that demonstrates the simplest possible boot code:

### Features
- Implements an infinite loop at the reset vector
- Uses the JMP instruction to jump to itself continuously  
- Properly sets up all interrupt vectors to point to the reset routine
- Fills unused ROM space with $FF

### Memory Map
- **ROM Start**: $E000 - Beginning of ROM space (adjustable)
- **Reset Vector**: $FFFE-$FFFF - Contains address of reset routine
- **Interrupt Vectors**: $FFF0-$FFFD - All point to reset routine for safety

### Assembly Instructions
To assemble this program, you'll need a 6809 assembler such as:
- **asm6809**: Modern cross-assembler for 6809
- **lwasm**: Part of the LWTOOLS package

Example assembly command:
```bash
asm6809 -o reset_loop.bin -l reset_loop.lst reset_loop.s
```

This will generate:
- `reset_loop.bin`: Binary ROM image
- `reset_loop.lst`: Listing file showing addresses and opcodes

### Programming to ROM
The binary output can be programmed to an EEPROM (such as AT28C256) using a programmer, or loaded into RAM for testing.

### Expected Behavior
When the 6809 processor executes this code:
1. On reset, the processor reads the reset vector at $FFFE-$FFFF
2. This vector points to the RESET label at $E000
3. The processor jumps to $E000 and executes `JMP RESET`
4. This creates an infinite loop, with the processor continuously jumping to the same address

This behavior can be verified using the serial monitor by observing:
- Constant address bus activity at $E000-$E002 (the JMP instruction)
- Repetitive instruction fetch cycles
- No progression to other addresses