## Context

I am building a dual-slot OTA system for the RP2040 (Pico W). The bootloader (Slot A) downloads a new firmware (Slot B) to flash and attempts to jump to it cleanly, without hardware reset. The bootloader manually sets SP, VTOR, and jumps into the new firmware's reset handler.

However, the new firmware was crashing early, leading to a multi-phase deep dive into startup mechanics, memory layout, and runtime assumptions.

---

## Summary of Discoveries

### Flash and RAM Layout

- **Bootloader (Slot A)**: 0x10000000 - 0x10064000
    
- **Boot Flag**: 0x10064000 - 0x10065000
    
- **Firmware B (OTA target)**: 0x10065000+
    

### Slot B Vector Table

- Word 0: Initial SP = 0x20042000 (was invalid, fixed to 0x20041FF0)
    
- Word 1: Reset Handler = Valid (e.g., 0x100660F7)
    

### What Went Wrong

1. **Invalid Stack Pointer**: SP initially set to 0x20042000 (outside valid RAM)
    
2. **Missing .data/.bss initialization**: Bootloader did not copy .data from flash to RAM or zero .bss for Firmware B.
    
3. **crt0.S was skipped**: No cold boot => No SDK startup logic => Bad runtime state.
    
4. **ROM state not initialized**: ROM-resident tables (used for float/double math) not initialized.
    
5. **AEABI tables not initialized**: `__aeabi_mem_funcs[]` (used by memcpy/memset) unpopulated.
    

---

## Debugging Techniques Used

- **GDB Jump Simulation**: Set SP, PC, VTOR manually; used `stepi` to walk early firmware instructions.
    
- **Memory Inspection**: Verified RAM contents before and after memory initialization.
    
- **Symbol Inspection**: Used `nm`, `objdump` to examine linker symbols like `__etext`, `__data_start__`, `__bss_start__`.
    
- **Assembly Reasoning**: Reverse engineered ROM initialization expectations.
    

---

## Solutions Identified

### Short-Term Fixes

- Hardcode `firmware_mem_init()` with addresses from Firmware B's ELF.
    
- Explicitly set SP, VTOR, and call reset handler.
    
- Manually fake ROM tables needed for SDK runtime.
    

### Long-Term Improvements

- Redesign bootloader to exit after jump and yield RAM fully to firmware.
    
- Build Firmware B with a minimal `crt0.S` tuned for OTA jump.
    
- Possibly move to watchdog-triggered soft resets in production for clean startup state.
    

---

## crt0.S Understanding

`crt0.S` does the following at cold boot:

- Set initial SP
    
- Copy .data section from flash to RAM
    
- Zero .bss section
    
- Initialize C++ constructors
    
- Call `main()`
    

By skipping `crt0`, manual OTA jumps must:

- Manually copy .data and .bss
    
- Manually fix the environment (ROM tables, AEABI tables)
    
- Prepare for runtime to safely execute
    

---

## System Design Reflection

### Can RP2040 do OTA properly?

- **Yes**, but it requires manual bootstrapping work.
    
- It expects cold boot memory state, which must be manually reconstructed.
    

### Should RAM be split between Bootloader and Firmware?

- **No**, in production, the bootloader should relinquish RAM after OTA jump.
    
- Bootloader only needs RAM temporarily during update/download, not after jump.
    

---

## Next Steps

- Finish stable `firmware_mem_init()` based on firmware B's linker addresses.
    
- Move bootloader `.data` and `.bss` above 0x20003000 temporarily (if needed).
    
- Test cleanly jumping after minimal memory preparation.
    
- Later: consider replacing bootloader with watchdog soft-reset jump.