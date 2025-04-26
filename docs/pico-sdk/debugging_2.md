**OTA Jump Debugging Breakdown - Pico W Bootloader to Firmware B**

---

**Background**
Rob is implementing an OTA (Over-The-Air) firmware update system on the Raspberry Pi Pico W using CMake, custom linker scripts, and a manually controlled bootloader. The bootloader resides in flash from 0x10000000 to 0x10064000 (400KB), with a 4KB OTA flag region following it. Firmware B is written at the offset 0x10065000.

The goal is to have the bootloader detect that a new OTA firmware image has been written and then jump to it cleanly, mimicking a hardware reset by setting the appropriate stack pointer (SP), program counter (PC), and Vector Table Offset Register (VTOR).

---

**Initial Successes**
- Bootloader logic runs successfully and halts in GDB.
- Firmware B is correctly written to the 0x10065000 offset.
- Vector table at 0x10065000 contains plausible values:
  - Word 0: Initial stack pointer = `0x20042000` (later revealed to be invalid)
  - Word 1: Reset handler = `0x100660f7`
- Disassembly of `0x100660f6` (Reset_Handler) reveals the instruction `movs r0, r5`, which fails because `r5` is uninitialized.

---

**First Roadblock: Invalid Stack Pointer**
GDB throws `Failed to read memory at 0x20042000` when attempting to set the stack pointer, revealing that the firmware's vector table specified an invalid SP address. RP2040's RAM only goes up to `0x20041FFF`, making `0x20042000` out of range.

**Fix**
- Update the stack pointer in the vector table to `0x20040000` or similar valid top-of-RAM address.
- Rebuild or patch firmware B accordingly.

---

**Second Roadblock: Broken Reset Handler**
The Reset vector pointed to `_reset_handler`, which began with `movs r0, r5`, a broken and invalid startup sequence.

**Diagnosis**
- `nm` revealed that `_reset_handler` was being linked but not properly used as a startup routine.
- Firmware was not linked with a valid `crt0` or SDK-style startup file.

**Fix Direction**
- Use the Pico SDK's `crt0.S` or write a minimal custom `Reset_Handler` that sets up `.bss`, `.data`, and calls `main()`.
- Confirm that the firmware linker script uses `ENTRY(Reset_Handler)`.

---

**Jump Code Implementation**
Rob then implemented an inline assembly block to perform the jump from bootloader to firmware B. It attempted to:
- Load OTA vector table address
- Load initial stack pointer and reset handler from the table
- Set MSP
- Set VTOR
- Jump to reset handler using `bx`

**Third Roadblock: Assembler Errors**
When building, the assembler threw errors like:
```
Error: invalid offset, value too big (0xFFFFFFFFFFFFFFFC)
```
This happened because inline assembly attempted to use memory constraints (`"m"`) and direct offsets (`ldr r1, [r0, #4]`) that couldn't be encoded in Thumb instructions.

**Fix**
- Replace `"m"` constraints with `"i"` (immediate values).
- Use `ldr r0, =...` to load addresses into registers.
- Avoid offset-dereferencing with `#4` by computing addresses explicitly in separate registers.

---

**Current Status (Stalled)**
- Bootloader is running and OTA binary is present.
- Stack pointer and reset vector are now correct.
- Firmware B is likely valid, but assembler errors in the jump code prevent a successful build.
- We are stalled on a build error caused by overly large offsets or improper address constraints in inline assembly.

---

**Next Step**
Fix the jump code with proper inline assembly syntax using register-loaded addresses and immediate values. Alternatively, move the jump logic into a dedicated `.S` file or `naked` C function for better portability and less constraint ambiguity.

