# OTA Firmware Jump Debugging Session Summary

## Context
Rob is building a dual-partition OTA update system for the Raspberry Pi Pico W using C++. A minimal bootloader downloads a new firmware binary from an EC2-hosted manifest and writes it to a known flash address (e.g., `0x10080000`). The bootloader is then responsible for jumping into the newly flashed firmware.

The primary issue faced during this session was that although the new firmware was being compiled and written correctly to flash, it failed to execute upon jumping. Instead, the system entered a hard fault or stalled silently.

---

## Technical Goals
1. Compile a valid firmware binary intended to run from `0x10080000`.
2. Populate the vector table at that address with a valid initial stack pointer and reset handler.
3. Implement a `jumpToB()` method in the bootloader that correctly loads the SP and jumps to the reset vector.

---

## Approaches Attempted

### 1. Linker Script Adjustments
- Defined `MEMORY` section:
  ```ld
  MEMORY {
    FLASH(rx) : ORIGIN = 0x10080000, LENGTH = 512K
    RAM(rwx)  : ORIGIN = 0x20000000, LENGTH = 256K
  }
  ```
- Ensured `.text`, `.data`, and `.bss` were placed appropriately.
- Attempted various linker entry points: `_entry`, `_entry_point`, `firmware_entry`, and `vector_table`.

### 2. Reset Vector Initialization
- Discovered that the second word in the vector table (`reset_vector`) was `0x00000000`, causing execution to stall or hard fault.
- Verified using `xxd`:
  ```bash
  xxd -g 4 -l 8 firmware.bin
  00000000: 00000420 00000000
  ```
- Verified `firmware_entry` is defined and present in the ELF symbol table:
  ```bash
  arm-none-eabi-nm -n firmware.elf | grep firmware_entry
  1008c1dc T firmware_entry
  ```

### 3. Jump Logic in Bootloader
- Used standard `jumpToB()` with:
  ```cpp
  uint32_t sp = *(uint32_t*)(app_base);
  uint32_t entry = *(uint32_t*)(app_base + 4);
  __asm volatile("msr msp, %0" :: "r"(sp));
  ((void (*)())entry)();
  ```
- Confirmed the system stalled due to invalid entry address or unpopulated vector.

---

## GDB & Binary Inspection
- `arm-none-eabi-objdump -x firmware.elf` showed valid section placement.
- `.vectors` section confirmed to be present, but reset handler was unresolved.
- Manually inspected vector table and symbols.

---

## Final Hypothesis
Despite correct linking and symbol availability, the reset vector was not being populated into the final `.bin` due to C++ name mangling or the way the vector table was declared.

---

## Path Forward
1. Explicitly define and reference `firmware_entry` using `extern "C"` and disable name mangling:
   ```cpp
   extern "C" void firmware_entry();
   extern "C" const void *vector_table[] __attribute__((section(".vectors"))) = {
       (void*)0x20042000,
       (void*)((uintptr_t)&firmware_entry | 1),
   };
   ```
2. Confirm this fixes the second word in the vector table:
   ```bash
   xxd -g 4 -l 8 firmware.bin
   00000000: 20042000 dc01 08 10
   ```
3. Resume OTA flow testing and verify execution successfully transfers into firmware B.

---

## Conclusion
The session revealed that the build was mostly correct, but execution stalled because the reset vector was missing or null due to C++ linkage ambiguity. Ensuring an explicit `firmware_entry` symbol reference with the Thumb bit resolved should enable successful jumps to the OTA firmware.

