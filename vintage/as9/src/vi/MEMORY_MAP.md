# VI Editor Memory Map

## Final Memory Layout (Verified & Tested)

### System Reserved Areas
```
$0000-$00FF  : Zero page (ASSIST09 direct page)
$0100-$01FF  : Stack (256 bytes, SP=$01FF grows down to $0100)
$0200-$03FF  : Reserved for future expansion (512 bytes)
```

### Program Code
```
$0400-$0925  : VI Editor code (1318 bytes actual)
$0926-$0FFF  : FREE - Program growth space (1755 bytes available)
```

### Active Edit Buffer
```
$1000-$172F  : TEXTBUF - Active text buffer (1840 bytes = 80×23)
$1730-$173F  : Gap (16 bytes)
```

### Editor State Variables
```
$1740        : CURX - Cursor X position (0-79)
$1741        : CURY - Cursor Y position (0-79)
$1742        : MODE - Editor mode (0=cmd, 1=ins, 2=colon)
$1743        : BSKEY - Backspace key type (BS or DEL)
$1744-$174D  : CMDBUF - Colon command buffer (10 bytes)
$174E        : CMDLEN - Command buffer length
$174F-$1752  : NUMBUF - Number conversion buffer (4 bytes)
$1753        : Reserved alignment byte
```

### File Save Slots (10 slots × 1842 bytes each)
Each slot: 2-byte 'VI' marker + 1840 bytes data = 1842 bytes ($732)

```
$1754-$1E85  : Slot 0 (SAVEBUF - default save location)
$1E86-$25B7  : Slot 1
$25B8-$2CE9  : Slot 2
$2CEA-$341B  : Slot 3
$341C-$3B4D  : Slot 4
$3B4E-$427F  : Slot 5
$4280-$49B1  : Slot 6
$49B2-$50E3  : Slot 7
$50E4-$5815  : Slot 8
$5816-$5F47  : Slot 9
```

### Free Space for Future Features
```
$5F48-$6FCF  : FREE (4232 bytes available)
```

### ASSIST09 Reserved Areas
```
$6FD0-$6FDC  : DISASSEMBLER variables (DO NOT USE)
$6FE0-$6FFC  : TRACE variables (DO NOT USE)
$7000-$7051  : ASSIST09 workspace (DO NOT USE)
$F800-$FFFF  : ASSIST09 ROM
```

## Memory Safety Verification

✅ **Program → TEXTBUF**: $0925 → $1000 = **1755 bytes clearance**  
✅ **TEXTBUF → Variables**: $172F → $1740 = **17 bytes gap**  
✅ **Variables → SAVEBUF**: $1752 → $1754 = **2 bytes gap**  
✅ **Last slot → ASSIST09**: $5F47 → $6FD0 = **4233 bytes free**

## Total Memory Usage

- Program code: 1,318 bytes (13% of available)
- Text buffer: 1,840 bytes
- Editor vars: 20 bytes
- Save slots: 18,420 bytes (10 × 1,842)
- **Total used**: 21,598 bytes
- **Total available**: ~28KB ($0200-$6FCF)
- **Utilization**: 75%

All memory regions properly aligned with NO overlaps!
