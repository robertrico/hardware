I set out to explore **Zephyr RTOS** to understand its potential role in modern embedded development. I was curious about how it abstracts hardware, enforces structure, and integrates with a wide range of boards, including the **Raspberry Pi Pico W (RP2040)** — a chip I’ve spent a lot of time with recently.

Through hands-on experimentation and reading, it became clear that **Zephyr offers major benefits** for certain kinds of organizations and projects:
- If you're building **complex systems** with many interchangeable components
- If you're in a **Linux-heavy or software-discipline-first company** looking to enforce consistency across embedded firmware
- If you value **maintainability and reuse** over bare-metal speed and minimalism

The configuration system and device tree overlays can be powerful. I can now see how you could spin up projects with interchangeable modules, swapping in components and mapping them cleanly to drivers and subsystems — and that’s no small feat.

However, I also discovered the **tradeoffs** for someone like me:
- I found myself buried in configuration files, overlays, and Kconfig options just to get a **simple PWM pin working**
- The actual *code* to blink an LED or generate PWM was just a few lines — trivial
- But understanding how the board was brought up, how the RP2040 was defined, and how drivers were selected felt like learning *someone else’s abstraction*, not mine

---

## What I Learned

- How Zephyr bootstraps and configures hardware using devicetrees and board definitions
- How to locate and manipulate the PWM subsystem through driver APIs
- How abstraction layers can *both help and hinder* depending on your goals
- That while Zephyr is production-grade, it may **obscure the very system behaviors I’m trying to master right now**

---

## Why I'm Stepping Back

I’m not just trying to blink LEDs or write feature code — I’m trying to deeply understand how firmware systems are built from the metal up:
- What bootloaders do
- How memory is laid out
- How linker scripts control where your code lives
- How to flip bits in registers and bring up a peripheral without someone else’s glue logic

Zephyr is a powerful tool — but right now, it’s too far removed from the raw behavior I want to learn and control. So I’m returning to my **hand-built CMake projects** using the **Pico SDK**, where I’ve got full control over memory, linker scripts, and peripheral configuration.
