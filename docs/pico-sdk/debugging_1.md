# OTA Firmware Jump Debugging and Root Cause Analysis

## Context
This project implements an OTA (Over-the-Air) firmware update system for the Raspberry Pi Pico W, with a bootloader (Slot A) and an updateable application firmware (Slot B). The bootloader downloads the new firmware over Wi-Fi, writes it to flash, sets a boot flag, and then attempts to jump to the new firmware in Slot B.

While the OTA download and flash process completes successfully, jumping to Slot B results in a double fault and processor lockup, halting execution.

---

## System Layout

### Flash Regions
- **Bootloader (Slot A)**: `0x10000000` - `0x10064000` (400 KB)
- **Boot Flag**: `0x10064000` - `0x10065000` (4 KB)
- **OTA Firmware (Slot B)**: `0x10065000` onwards

### Slot B Vector Table (confirmed live):
```text
0x10065000: 0x20042000 (initial stack pointer)
0x10065004: 0x100660F7 (reset handler / entry point)
```

---

## Debugging Approach

### Jump Setup (GDB):
```gdb
set $sp = *0x10065000
set $pc = (*0x10065004) & 0xFFFFFFFE
set *(uint32_t*)0xE000ED08 = 0x10065000
set $xpsr = 0x01000000
stepi
```

### Outcome
- Successfully lands at `0x100660F6: movs r0, r5`
- `r5 = 0x00000000` (valid)
- Stepping causes double fault on or after `movs r0, r5`

### Fault Confirmation
- `pc: 0xfffffffe` after crash
- Double fault consistently occurs when jumping to Slot B
- Flash content and vector table are valid

---

## Root Cause

**Missing runtime initialization in Slot B**

- No startup routine to:
  - Copy `.data` from flash to RAM
  - Zero `.bss`
  - Call `main()`
- Firmware jumps into a midstream function where global state (e.g., `r5`) is assumed valid but is uninitialized
- No CRT (`crt0.S`) or `_entry_point()` logic exists in Slot B

---

## Comparison to Hunter Adams' Method
- Hunter's application firmware links against `pico_stdlib`
- He relies on the Pico SDK's `crt0.S` to perform all startup tasks
- His linker and build setup ensures safe execution from `main()`

---

## Proposed Fix
### Option 1: Use Pico SDK in Slot B
- Link firmware against `pico_stdlib`
- Include `target_link_libraries(firmware pico_stdlib)`
- Let SDK handle all startup logic

### Option 2: Add Manual Startup Logic
Implement `_entry_point()` in C:
```c
extern uint32_t _data_load, _data, _edata;
extern uint32_t _bss_start, _bss_end;

void _entry_point(void) {
    uint32_t* src = &_data_load;
    uint32_t* dst = &_data;
    while (dst < &_edata) *(dst++) = *(src++);

    dst = &_bss_start;
    while (dst < &_bss_end) *(dst++) = 0;

    main();
    while (1);
}
```
And define these symbols in the linker script:
```ld
_data = .;
*(.data)
_edata = .;
_data_load = LOADADDR(.data);

_bss_start = .;
*(.bss)
_bss_end = .;
```

---

## Status
- OTA download and flash verified functional
- Slot B vector table is valid
- Jump correctly loads SP and PC
- Execution enters firmware but crashes on first instructions due to missing `.data` and `.bss` setup

---

## Next Steps
1. Choose runtime strategy (manual startup or link to Pico SDK)
2. Validate Slot B map file for correct `.data`, `.bss`, `.vectors`
3. Implement `_entry_point()` or equivalent
4. Verify `main()` is reached and runs post-jump

---

## Lessons Learned
- A valid vector table is not sufficient — startup environment must be safe
- Minimal firmware must still include a full runtime init path
- GDB-based manual jumps are invaluable for post-flash validation
- Double faults often trace back to assumed state being invalid

