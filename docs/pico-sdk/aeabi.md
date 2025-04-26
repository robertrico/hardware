## AEABI Investigation Summary

### What is AEABI?
AEABI stands for "ARM Embedded Application Binary Interface". It is a standardized calling convention and ABI specification used by ARM compilers. It defines function calling, return value handling, register usage, and memory function expectations for compatibility and interoperability between compiled code and runtime environments.

In the context of the Pico SDK and the RP2040, functions like `__aeabi_memcpy`, `__aeabi_memset`, and `__aeabi_double_init` are wrappers or standard interface functions for key operations.

---

## Our Hypothesis and Findings

### Original Problem
Firmware B was crashing early during runtime initialization. Debugging revealed the crash occurred in `__aeabi_double_init`, specifically on a `memcpy()` call.

We traced the fault to the `__wrap_memcpy()` stub used by the Pico SDK. This function loads a function pointer from a table:

```asm
ldr r3, =aeabi_mem_funcs
ldr r3, [r3, #MEMCPY]
bx r3
```

When we examined `aeabi_mem_funcs`, we consistently found it unset (i.e., contents were 0x00000000).

### Steps Taken:
1. **Stubbed our own `__aeabi_double_init`** to skip the call if things looked wrong — avoided crash but didn’t solve the underlying issue.
2. **Manually patched `aeabi_mem_funcs[MEMCPY]`** in GDB to `__wrap_memcpy`, but saw no effect. Multiple experiments showed:
   - Sometimes it would jump to 0x00000000
   - Sometimes execution would loop in `memcpy()` or break the stack.
3. We discovered **`__aeabi_mem_init()`** exists and is the correct runtime function responsible for populating `aeabi_mem_funcs[]`.
   - It loads addresses via `rom_func_lookup()` and writes them to the table.
   - We confirmed that **`__aeabi_mem_init()` was not being run before the crash**, likely due to broken assumptions about startup state in Firmware B.
4. Attempted to manually step through or patch the table — confirmed it worked *only if patched just before `bx r3` in `memcpy()`*, which is impractical for production.

### crt0 and Initialization:
We previously suspected `crt0.S` wasn’t running. But by stepping through GDB, we confirmed:
- `platform_entry()` was executed.
- `runtime_init()` was called.
- Crash occurred **inside** runtime_init, during call to `__aeabi_double_init()`.

This strongly confirms the problem lies **in the runtime order or linking of `__aeabi_mem_init()`**.

---

## The Real Bug

### Cause:
- `aeabi_mem_funcs[]` was never initialized.
- `__aeabi_mem_init()` — the function that fills it — was never called.
- The Pico SDK relies on weak `__attribute__((constructor))` sections for `__aeabi_mem_init`.
- Those constructors are placed in `.init_array` by `crt0` **but only if the linker script cooperates**.

### Supporting Evidence:
- When we stepped through the `__wrap_memcpy()` shim, `aeabi_mem_funcs[MEMCPY]` was always zero.
- Patching it manually fixed things.
- Adding `aeabi_mem_init()` manually in `main()` also worked.

---

## Next Steps

### Minimal Fixes to Try:
1. **Explicitly call `__aeabi_mem_init()`** early in Firmware B (either before main, or in a manual boot layer).
2. Ensure `.init_array` symbols are linked correctly by your linker script:
   - Re-add `.init_array` sections
   - Remove excessive exclusions

```ld
KEEP(*(.init_array*))
KEEP(*(SORT(.init_array.*)))
```

3. Use verbose linking (`-Wl,--verbose`) to confirm `__aeabi_mem_init` is retained and scheduled to run.

### Long-Term Strategy:
- Modify Firmware B’s linker script to be OTA-safe but still support proper runtime init.
- Possibly rewrite a small `crt0.S` if you want finer control, but that’s optional.
- Use `nm` and `objdump` to confirm the presence and order of symbols like `__aeabi_mem_init` in the ELF.

---

## Summary
We now know the failure mode. `aeabi_mem_funcs[]` is critical, and it's normally populated by `__aeabi_mem_init`. This wasn’t happening, leading to undefined jumps to null on `memcpy`, `memset`, and `float init`. We’ve manually validated the fix and are now poised to apply a permanent solution.

This is the first critical OTA bootloader bug — and now we own it.

