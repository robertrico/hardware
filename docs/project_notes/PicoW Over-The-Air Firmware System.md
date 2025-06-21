## The Intent

I intended to try and create a dual-partition bootloader/firmware system using the PicoW alongside the [[pico-sdk]]. The goal was to build a foundational platform for future projects, possibly enabling remote updates. Given the practical use for my rover and embedded projects, it was a strategic and logical investment.

## The Hurdle

The RP2040 on the PicoW demands the assumption of a cold boot to properly enter `_entry_point`, `platform_entry`, `aeabi_init_*`, and `preinit` routines within `crt0.S`. These routines run perfectly from cold boot, but issues arise when trying to manually jump from a bootloader to new firmware. The 256 bytes used during boot (`SRAM5` at `0x20040000`) [[256]] must be respected, and critical ROM-resident tables (at `0x18` and `0x1C`) are normally set only at power-on reset. A proper cold-boot-like environment must be recreated manually before jumping. Address offsets, linker scripts, and manual bootstrapping are all essential to solving this problem.

## The Attack

In the [[OTA]] project, the initial approach was exploratory and chaotic, a necessary brute-force dive into unknowns. This revealed critical insights:

- The first 256 bytes at flash address `0x10000000` are CRC-verified and copied to SRAM5 during boot [[Eurkeka!]].
    
- ROM expectations must be manually reconstituted to avoid hard faults, especially for floating-point ABI tables and memory functions [[aeabi]].
    
- Bootstrapping `.data`, `.bss`, and runtime memory is mandatory before executing firmware logic [[ota_bootstrap]].
    
- Firmware must be carefully linked with valid vector tables, linker symbols, and entry points [[linker]].
    
- Jumping must respect ARM Cortex-M conventions, such as setting `lr` to a nonzero trap value to avoid `bx lr` crashes [[linker]].
    

This journey transitioned from random hacking into structured learning about C, C++, assembly, ARM EABI, linker scripts, startup flows, and deep system initialization.

## The Support

Along the way, key resources were found:

- Hunter Adams' RP2040 teaching labs https://github.com/vha3/Hunter-Adams-RP2040-Demos/tree/master/Bootloaders/Serial_bootloader
    
- JZimnol's pico_fota_bootloader https://github.com/JZimnol/pico_fota_bootloader/tree/master
    
- Extensive direct reading of the Pico SDK source code
    
- ARMv6-M Architecture Reference Manual and RP2040 datasheet
    

AI tools assisted but could not bridge the gap alone. Real progress came when stepping into GDB, disassembling memory regions, manipulating raw memory at addresses like `0x20040000`, and observing the consequences.

## Key Learnings

- **Memory State Matters**: Manual OTA jumps must recreate what the ROM would normally initialize. Forgetting even a single ROM-resident table causes crashes.
    
- **Runtime Bootstrapping is Fragile**: `__aeabi_mem_init()`, `rom_data_lookup()`, and initialization of `.data` and `.bss` sections are mandatory.
    
- **Jumping is an Art**: Proper SP, PC, VTOR, and `lr` setups are all needed to achieve a clean handoff without undefined behavior.
    
- **Linker Control is Critical**: Correct memory mappings, section placements, and symbol exports are vital for startup correctness.
    
- **Unified Build Pipelines Matter**: Fragmented bootloader and firmware projects cause inconsistencies. Consolidated builds with shared flash layouts are the right approach [[OTA v2]].
    

## The Pivot

Recognizing the complexity, this project will evolve into a clean, minimal OTA framework ("OTA_2") [[OTA v2]]. The future system will:

- Enforce strict flash layout definitions
    
- Respect the 256-byte SRAM5 region
    
- Provide clean, explicit jump code with cold-boot emulation
    
- Grow cautiously, layering in security features only after runtime correctness is fully proven
    

## Conclusion

This phase of the project was not about "shipping" OTA updates. It was about wrestling the RP2040 to the ground, exposing every assumption hidden inside the Pico SDK and ARM runtime systems. Now that the knowledge is earned, future work on OTA_2 can proceed with precision, building on a far more stable and deeply understood foundation. That is, if chosen to proceed on such an endeavor.

[[pico-sdk]] [[ota_bootstrap]] [[256]] [[linker]] [[aeabi]] [[Eurkeka!]] [[OTA v2]]