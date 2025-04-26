# Assembly Reasoning: Reverse Engineering — OTA Jump and ROM Behavior on RP2040

## Objective
Understand why `__aeabi_double_init()` fails after a jump from a custom bootloader (Firmware A) to another firmware (Firmware B) on the RP2040. The goal was to reverse engineer the behavior of the SDK and ROM and establish the minimum required state to allow post-jump firmware to initialize and run successfully without causing `HardFault`s.

## Initial Observations
- Jumping from Firmware A to Firmware B using a direct memory jump (setting MSP, VTOR, and branching to the reset handler) leads to a HardFault early during `runtime_init()`.
- Backtrace from GDB confirms crash happens inside `__aeabi_double_init()`.
- The function fails while attempting to assert a valid soft float table pointer obtained via `rom_data_lookup(rom_table_code('S', 'F'))`.

## Assembly-Level Hypothesis
- The SDK expects the ROM to have initialized:
  1. `*(uint16_t*)0x18` with the function pointer to `rom_table_lookup()`
  2. `*(uint16_t*)0x1C` with a pointer to the soft float table
  3. A valid two-byte header at `rom_table_float - 2` (typically `0x24A`) with the type and size (in words)

- The assert that fails in `__aeabi_double_init()` is:
```c
assert(*((uint8_t *)(((void *)rom_table_float)-2)) * 4 >= SF_TABLE_V2_SIZE);
```

- A ROM boot (power-on reset or watchdog) normally sets these values.

## What We Confirmed in GDB
- Disassembly confirms `rom_table_lookup()` resides at `0x001D`.
- Reading `*(uint16_t*)0x18` showed it was zero or incorrect, i.e., ROM lookup vector was not set.
- Reading `*(uint16_t*)0x1C` yielded a bogus address (`0x2300`), pointing to what looks like junk.
- Disassembly of `0x2300` confirms it is not a valid table, just arbitrary memory content.
- The soft float table at `0x24C` *does* exist and contains valid entries, but the two bytes preceding it (`0x24A`) are `0x00 0x00`.

## Root Cause
- The ROM-resident initialization code never ran, therefore the SDK's assumption about the system being in a cold-booted state is violated.
- Because Firmware A jumps to Firmware B without a reset (power-on or watchdog), the memory-mapped metadata normally configured by the ROM boot is uninitialized.
- Specifically:
  - `rom_data_lookup()` fails due to `0x1C` being incorrect
  - Even if forced, `__aeabi_double_init()` would fail the size check on the soft float table header

## Experiments Tried

### 1. Wrapping `__aeabi_double_init()`
- Used linker `--wrap` to override `__aeabi_double_init()`
- Verified override executes in place of SDK version
- Implemented a guard:
```c
if (*(uint16_t*)0x1C < 0x100 || *(uint16_t*)0x1C > 0x1000) return;
```
- This bypassed the assert and allowed Firmware B to run

### 2. Reconstructing ROM Boot State ("Fake ROM")
Inserted before the jump in Firmware A:
```c
*(uint16_t*)0x18 = 0x001D;
*(uint16_t*)0x1C = 0x024C;
((uint8_t*)0x24A)[0] = 0x01;
((uint8_t*)0x24A)[1] = 0x40; // = 0x40 * 4 = 256 bytes
```
- This recreates the exact environment the ROM sets up at cold boot
- With this in place, no wrap or patch to `__aeabi_double_init()` is needed
- Firmware B boots successfully

## Conclusion
The RP2040 mask ROM performs system-critical memory initialization which the Pico SDK silently depends on. If a firmware image is launched via jump without going through cold boot (or watchdog reset), certain assumptions fail:
- Lookup functions are not wired
- Float/double ABI tables are invalid
- HardFaults result due to dereferencing or asserting against garbage

A safe OTA loader must either:
1. Perform a watchdog reset and write to `scratch[0]` to inform the next stage
2. Manually replicate ROM boot setup: VTOR, soft-float tables, and ROM lookup tables

By reverse engineering the ROM behavior and SDK dependencies, we’ve demonstrated how to reconstruct the required boot environment in RAM and enable a non-reset jump to another firmware partition safely.

This opens the door to a proper PR for `pico-sdk`, possibly introducing a macro like `PICO_ASSUME_ROM_BOOT=0`, allowing the SDK to gracefully bypass or validate against known ROM-initialized memory.

