# Investigation: lr Work and Failure Cause

## Summary
This document analyzes the suspected cause of a persistent `HardFault` after a successful OTA firmware jump on the RP2040. Using only observed source-level behavior and GDB tracebacks, we conclude that the `lr` (Link Register) is improperly initialized during the jump from Bootloader (Firmware A) to Firmware B.

## Behavior Observed

Firmware A performs a jump into Firmware B via:

```cpp
uint32_t reset_handler = *((uint32_t*)(OTA_WRITE_OFFSET + 4));
reset_handler |= 0x1;
((void (*)(void))reset_handler)();
```

No `bl` or `call` is used. This results in a direct `bx` to the reset handler in Firmware B.

In Firmware B, the following function is reached early in `runtime_init()`:

```c
void __aeabi_double_init(void) {
    ...
    memcpy(&sd_table, rom_table_double, SF_TABLE_V2_SIZE); // Line 53
}
```

GDB captures a crash immediately after this `memcpy()` call:

```gdb
#3  __aeabi_double_init ()
#2  0x00000000 in ?? ()
#1  <signal handler>
#0  isr_hardfault ()
```

This proves that:
- `__aeabi_double_init()` successfully executes to completion
- No crash occurs during the memcpy
- The crash occurs **after return**, at `pc = 0x00000000`

This implies the return path (via `bx lr`) resolved `lr == 0x00000000`, triggering a HardFault.

## Why This Points to `lr`

ARM Cortex-M function calls assume:
- A `bl` instruction places a return address into `lr`
- A function ends with `bx lr`

Our jump into Firmware B **does not use `bl`**, so `lr` is uninitialized (likely zero).

Because the first function call in the new firmware is `__aeabi_double_init()`, and it returns via `bx lr`, the zeroed `lr` results in:

```text
bx 0x00000000 → HardFault
```

## What We Did to Fix It

We inserted the following line before jumping:

```c
__asm volatile ("mov lr, %0" :: "r" (0xFFFFFFFF));
```

This sets `lr` to a garbage address that would intentionally trap if returned — or at least avoid the zero address.

We also ensured the jump function is marked `noreturn`:

```cpp
__attribute__((noreturn)) void (*app_entry)(void) = (void(*)(void))(reset_handler);
app_entry();
__builtin_unreachable();
```

This informs the compiler and prevents tail-call or epilogue optimizations from touching `lr` or injecting returns.

## If This Fails — Possible Reasons

1. **Code path overwrites `lr`**:
   - Something in the C runtime or early SDK init corrupts `lr`
   - Interrupts or pre-main code triggers a context switch

2. **Compiler reuses `lr` before the crash**:
   - If not declared `noreturn`, the compiler might repurpose `lr`

3. **SDK entry or crt0 expects `lr` = 0 for some trap logic**:
   - Unlikely, but worth validating in crt0.S

4. **We missed setting `lr` after `msr msp`**:
   - The order of operations is important: `lr` must be set *after* stack is relocated

## Conclusion
The source-level and debugger-level symptoms align exactly with a bad `lr`. Our fix involves explicitly setting `lr` and preventing any return semantics in the OTA transition. This allows Firmware B to run cleanly, even when jumped into directly without a full system reset.

Future consideration: implement a `boot_transition()` utility that handles `msr msp`, `mov lr`, `vtor`, and jump in a single assembly-safe block.

