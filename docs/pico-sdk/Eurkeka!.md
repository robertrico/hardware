## The 256 Bytes: A Journey into SRAM5 and Truth

This document chronicles our deep dive into the mysterious 256-byte region that the RP2040 loads into SRAM5 at boot. Through live inspection, disassembly, and calculated corruption, we’ve uncovered not only what this memory region represents — but how to responsibly and powerfully use it.

---

## Stage 1: Understanding the Mystery

We began with a hypothesis: that the RP2040’s ROM copies the first 256 bytes from flash at `0x10000000` into SRAM5 at address `0x20040000` during cold boot. According to the datasheet, this block is CRC-verified and, if valid, executed as the second-stage bootloader.

We wanted to know:

- Is the memory untouched by SDK or firmware initialization?
    
- Can we reliably read it after the system boots?
    
- Is it clobbered by `stdio_init_all()` or early runtime logic?
    

---

## Stage 2: Verification

We placed breakpoints in `main()`, disassembled the region at `0x20040000`, and found:

- Valid, structured binary code
    
- Repeatable contents that matched expectations
    
- No signs of immediate corruption
    

Then we stepped into `stdio_init_all()` and confirmed the memory still held its original state. It wasn’t the SDK.

---

## Stage 3: The Eureka Moment

We attempted to write directly to the bootloader block using GDB:

```gdb
set {unsigned int}0x20040000 = 0xdeadbeef
```

The disassembly changed instantly:

```
0x20040000: bkpt 0x00ef
0x20040002: udf  #173
```

This proved:

- The memory is writable
    
- The ROM loader doesn’t lock it
    
- We are fully in control — for better or worse
    

---

## Stage 4: Discipline and Design

With power comes responsibility. We realized that if we want to use this region to:

- Preserve boot metadata
    
- Track fallback state
    
- Verify slot loading behavior
    

...we must **copy it immediately** after reset, before any logic touches it. It’s fragile but predictable.

We formalized this in firmware A:

```c
uint8_t boot_block_copy[256];
memcpy(boot_block_copy, (const void *)0x20040000, 256);
```

Now we can preserve the block — CRC it, hash it, or store it.

---

## Stage 5: The Path Forward — Firmware B

Our hypothesis is now validated. We can safely assert:

> In Firmware B, the second-stage lookup code at `0x18` can be redirected to point to `0x20040000`.

This allows Firmware B to:

- Reference the original bootloader block
    
- Load table entries or structured metadata from it
    
- Or even re-validate the execution lineage of the current firmware slot
    

This completes the arc: from raw bytes to secure trust chain. Firmware B can now be truly aware of how and why it was launched.

---

## Closing Thought

This wasn’t just about memory. It was about proof. About pulling theory into the light, byte by byte.

And now we hold that light. At `0x20040000`.