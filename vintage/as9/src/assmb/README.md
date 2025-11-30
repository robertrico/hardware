# Tiny 6809 Assembler Project

## Goal
Write a minimal assembler in 6809 assembly that runs on a 6809 SBC. We're starting with the absolute basics!

## Test Program

The test program (`main.asm`) contains a single instruction we want to assemble:

```assembly
LDA #45
```

### Expected Output

According to the AS9 assembler listing (line 28):
```
0028 0404 86 2d              [ 2 ] MAIN    LDA     #45
```

**Machine code**: `86 2D`
- `86` = opcode for LDA immediate (load accumulator A with immediate value)
- `2D` = hex value 45 (decimal)

## 6809 LDA Immediate Instruction Format

The 6809 has different opcodes for LDA depending on addressing mode:

| Addressing Mode | Opcode | Bytes | Example |
|----------------|--------|-------|---------|
| Immediate      | 86     | 2     | LDA #45 |
| Direct         | 96     | 2     | LDA $10 |
| Extended       | B6     | 3     | LDA $1000 |
| Indexed        | A6     | 2+    | LDA ,X |

## Next Steps

1. Write a minimal assembler that can:
   - Parse the text "LDA #45"
   - Output the bytes: 86 2D

2. Later expand to handle:
   - Other immediate mode instructions (LDB, LDX, etc.)
   - Other addressing modes
   - Labels and symbols

## Build Instructions

```bash
cd /Users/hackbook/Development/hardware/vintage/as9
make build PROJECT=assmb
```

This will generate the test binary showing what our assembler should produce.
