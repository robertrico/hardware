**DINO v0.0.1 Wiring and Debug Summary**

---

**Power & Ground Discipline**
- Always confirm VCC/GND orientation from the power supply.
- Reversed polarity can cause 555 or other ICs to heat up or fail.
- Establish local ground nodes early to simplify wiring and decoupling.

**555 Timer Bring-Up**
- LED + resistor off pin 3 for visual test.
- Output blink confirmed using 1µF electrolytic cap; positive to timing node, negative to GND.
- Capacitance value directly affects blink speed; 68nF is fast, 1µF is slow.
- Control voltage pin (pin 5) should be tied to GND via 0.01-0.1µF ceramic cap.

**LED Orientation**
- Anode to current source (e.g., 555 output), cathode to GND.
- Reversed LED will not light.

**Reset Subsystem**
- MRC (~CCLR) is active-low; must be pulled high with 10kΩ resistor.
- Button connects MRC to GND for manual reset.
- Shared pull-up resistor is acceptable across multiple MRC pins.

**Program Counter (PC) with 74LS590**
- Stage A:
  - ~CE pulled LOW (enabled at all times).
  - CPC clocked from 555 timer.
- Stage B:
  - ~CE driven by RCO of Stage A (ripple carry).
  - CPC also clocked from 555.
  - CPR tied HIGH for real-time output.
- ~OE on both chips tied LOW to enable output.
- B counts 256x slower than A.
- RCO is a brief pulse, not a latched HIGH.

**Debug Findings**
- Confirmed that both ~CE pulled HIGH disables counting.
- Correct chaining requires:
  - 555 clock -> both CPC
  - ~CE A -> LOW
  - ~CE B <- RCO A

**Suggested Visual Debug Aids**
- Add LED on B.Q0 to visualize slower pulse (1 per 512 clocks).

**General Practices**
- Test subsystems incrementally.
- Watch pin functions and active-low indicators (~).
- Avoid floating inputs; tie with pull-ups or pull-downs.
- LED test rig is useful for visual validation of digital outputs.

**Next Steps**
- Complete schematic corrections (~CE wiring).
- Validate full 16-bit PC operation.
- Proceed to SRAM address decoding and wiring from PC bus.

---

DINO is alive. Power is disciplined. Timers are stable. Counter chain is operational.

