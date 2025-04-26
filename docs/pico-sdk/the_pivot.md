# The Pivot

## Summary

This marks a deliberate transition from the exploratory OTA_1 project into a focused, structured, and minimal OTA firmware system known as OTA_2. The goal is no longer to simply "get it working" — it is to build a **reusable, foundational OTA framework** that can be applied to any future embedded project from day one.

We are choosing not to clone or extend Jakob's repo directly, even though it is technically complete. As with many production-level examples, it comes with extra security layers, encryption, and abstractions that are unnecessary and potentially distracting at this stage. Security will be considered and implemented after the foundation is bulletproof.

## Key Realizations

1. **Jumping to firmware requires a structured handoff.**
   - The bootloader must set the MSP (Main Stack Pointer) and jump to the vector table entry of the new firmware.
   - Jumping to `main()` or beyond the reset handler in firmware B caused failures due to skipped runtime init (e.g., `__aeabi`, BSS, `.data`).

2. **The 256-byte boot block is untouched if we don't touch it.**
   - SRAM at `0x20040000` can be used for transient staging or boot flags, as long as it's respected by both linker and runtime.

3. **Flash layout must be explicitly defined and enforced.**
   - The bootloader, metadata (flash info), app, and download regions must be memory-aligned and declared clearly in the linker scripts.
   - A structured flash layout like Jakob's (bootloader -> flash_info -> app -> download) provides clarity and runtime assurance.

4. **The problem with OTA_1 was fragmentation.**
   - Firmware and bootloader lived in separate projects, introducing inconsistencies in how symbols were defined and data was handed off.
   - In contrast, both Hunter's and Jakob's projects **used unified builds**, reducing the surface area for mismatch.

---

## The New Repository (OTA_2)

### Structure
```
ota_2/
├── bootloader/
│   └── main.c
├── firmware/
│   └── main.c
├── common/
│   ├── linker_definitions.ld
│   └── flash_info.h
└── CMakeLists.txt
```

### Goals
- **Single build pipeline** for both bootloader and firmware
- Incremental growth:
  1. Start with only `.boot2` + `.text` + basic jump logic
  2. Add `.flash_info` region with fixed constants
  3. Introduce one rollback/swap flag at a time
  4. Add runtime checksum validation
  5. Extend with testable metadata checks

---

## Immediate Next Steps
- Build a clean bootloader project that:
  - Is linked to `0x10000000`
  - Contains a valid 256-byte `.boot2`
  - Reads a `LONG` address from `__flash_info_app_vtor`
  - Sets MSP and jumps to the firmware's reset vector

- Build a minimal firmware that:
  - Starts at `__FLASH_APP_START`
  - Blinks an LED or prints a message
  - Assumes nothing about OTA and exists just to validate jump

- Confirm memory layout via GDB:
  - Inspect values in `0x10000000`, `__flash_info_app_vtor`, `0x20040000`
  - Confirm jump works reliably after boot2 handoff

---

## Final Note
This is not a feature chase. OTA_2 is about understanding, simplicity, and correctness first. We are not skipping security — we are deferring it until we have a system we *trust*. Once that foundation exists, we'll begin layering:
- Metadata validation
- Flash signature verification
- Optional rollback
- OTA update staging logic

Until then, OTA_2 will grow by deliberate, observable steps.

