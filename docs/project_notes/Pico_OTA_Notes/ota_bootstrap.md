**Title: Bootstrapping RP2040 Runtime from Manual Firmware Jump (No Reset)

**Objective:**
Implement a complete runtime bootstrapping routine for the RP2040 that reproduces the cold boot environment when jumping from a bootloader (Firmware A) to a manually-jumped application (Firmware B), without triggering a watchdog reset.

---

## Phase 1: System Assumptions

Firmware B expects:
- `aeabi_mem_funcs` initialized to point to wrappers like `__wrap_memcpy`
- `sd_table` (double math dispatch table) correctly initialized
- Runtime `.data` section copied from flash to RAM
- Runtime `.bss` section zero-initialized
- Vector table set and `msp` configured

Firmware A (bootloader) is responsible for ensuring all of the above.


---

## Phase 2: Implementation Plan

### 1. Vector Table and MSP Setup (Already Implemented)
```cpp
__asm volatile ("msr msp, %0" :: "r" (*((uint32_t*)firmware_b_offset)) : );
*(volatile uint32_t*)0xE000ED08 = firmware_b_offset;
```

### 2. Initialize `aeabi_mem_funcs`
- Location: `0x20000270`
- Must initialize `aeabi_mem_funcs[1]` to point to `__wrap_memcpy`

```cpp
extern "C" void *__wrap_memcpy(void *, const void *, unsigned);
*(uint32_t*)(0x20000270 + 4) = (uint32_t)&__wrap_memcpy;
```

### 3. Initialize `sd_table`
- At address `&sd_table`, normally populated in `__aeabi_double_init`
- Need to simulate cold ROM behavior:

```cpp
#define SF_TABLE_V2_SIZE 0x80
uint32_t *rom_double = (uint32_t*)rom_data_lookup(rom_table_code('S','D'));
memcpy(&sd_table, rom_double, SF_TABLE_V2_SIZE);
```

Ensure:
- `rom_table_lookup()` works (initialize table pointer at `0x18` to `0x1D`)
- `0x1C` points to valid ROM data table or valid replica


### 4. Initialize `.data` and `.bss`
- Use values from `firmware_b.elf` symbol table or embed metadata

```cpp
extern uint32_t __data_start__, __data_end__, __data_load_start__;
extern uint32_t __bss_start__, __bss_end__;

memcpy(&__data_start__, &__data_load_start__, ((uintptr_t)&__data_end__ - (uintptr_t)&__data_start__));
memset(&__bss_start__, 0, ((uintptr_t)&__bss_end__ - (uintptr_t)&__bss_start__));
```

Note: Link firmware B with exported linker symbols or include `.map` parser.


### 5. Call Runtime Initializers
- Normally called in `crt0.S`:

```cpp
extern void __libc_init_array();
__libc_init_array();
```

Only needed if firmware B uses C++ global constructors or static initializers.


---

## Phase 3: Integration into Bootloader

```cpp
fix_rom_assumptions();
fix_memcpy_runtime();
fix_data_bss_runtime();

// Proceed with jump
jump_to_firmware_b();
```

All fixes must be carefully gated to avoid doing this when booting from a true cold start (e.g., watchdog).

---

## Risks
- ROM symbols change across SDK versions; fragile.
- Manual RAM manipulation is risky without CRC or manifest checks.
- Breaks with SDK changes unless tightly pinned.

---

## Recommendation
If this is a client requirement:
- Document exact SDK commit hash.
- Re-validate on each update.
- Consider splitting bootloader as a permanent partition with fixed behavior.
- Provide optional watchdog-based restart path for debugging and diagnostics.

---

## Validation
- GDB breakpoints confirm `__aeabi_double_init` executes safely
- Memcpy succeeds from ROM
- Stack and heap usable after transition
- Firmware B `main()` executes without crash or trap

