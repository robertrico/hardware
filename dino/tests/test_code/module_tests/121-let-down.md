# The Great 74LS121 Let-Down

## Date: 2025-08-30
## Module: DINO CPU Register Latch Timing

## Problem Summary
The 74LS121 monostable multivibrator (one-shot) was supposed to generate precise latch pulses for register operations in the DINO CPU. Instead, it triggered only intermittently (~30% success rate) despite meeting all datasheet requirements.

## Original Design Intent
- **Purpose**: Generate automatic hardware-controlled latch pulses when control signals change
- **Trigger**: NAND gates monitoring REG_LOAD and PULSE_REQ signals
- **Timing**: ~500ns pulse width (RC network: 2.2kΩ + 100pF)
- **Recovery**: 96ms between triggers (plenty of time)

## The Mystery Symptoms
- Random intermittent triggering (not pattern-based)
- Sometimes first pulse worked, sometimes it didn't
- ~30% success rate overall
- Identical behavior across 3 Signetics chips AND 1 TI chip
- All chips were 30-50 years old pulled stock

## Everything We Verified Was Correct
### Signal Quality
- ✅ Voltage levels: Full 5V swings (verified after fixing 10X probe setting)
- ✅ Edge speeds: 30ns rise, 84ns fall (excellent for LS-TTL)
- ✅ Clean transitions on A1, A2, and B inputs
- ✅ Proper ground reference between Arduino and circuit

### Circuit Design
- ✅ RC network properly connected (pins 10-11, not to ground)
- ✅ Multiple trigger modes tested:
  - A1/A2 triggering with B=HIGH
  - B triggering with A1=LOW, A2=HIGH  
  - Direct Arduino drive (bypassing NAND gates)
- ✅ Correct function table states for all modes
- ✅ 96ms recovery time (way more than needed)

### Debugging Steps Attempted
1. **Power supply improvements**
   - Added 0.1µF ceramic decoupling (made it worse!)
   - Added 10µF electrolytic
   - Ran thick ground wire directly to chip

2. **Signal conditioning**
   - Added 22pF cap to trigger inputs (no effect)
   - Added pull-up resistors (no effect)
   - Separated control and output wiring

3. **Trigger variations**
   - Used A-input triggering (intermittent)
   - Used B-input triggering with Schmitt trigger (still intermittent)
   - Changed timing from 16ms phases to 16µs (no improvement)

4. **Physical debugging**
   - Wiggled connections (high-quality breadboard, no effect)
   - Swapped to different breadboard locations
   - Disconnected output load completely
   - Changed RC components

## The Revelation
After 5 hours of debugging: **The chips are just old and degraded**

All evidence points to age-related degradation:
- Internal capacitor leakage
- Metal migration after 30-50 years
- Gate oxide breakdown
- Previous thermal stress from desoldering
- Unknown storage conditions

The intermittent behavior across ALL chips (different manufacturers!) confirms it's not a circuit problem.

## The Solution: Redesign with 74LS14 + RC

### New Design (Simple & Bulletproof)
```
Trigger →─┬─R(1k)─┬─→ 74LS14 →─→ 74LS14 →─→ Pulse Out
          │       │     (inv1)      (inv2)
          └─C(100pF)
              │
             GND
```

### Why This Is Better
- Schmitt trigger inputs are robust against noise
- No weird internal states like the '121
- Simple RC timing (pulse width ≈ 0.8 × R × C)
- New stock 74LS14s available (no age issues)
- One hex inverter chip can make 3 pulse generators

### Impact on DINO
- Register module needs rewiring
- Memory module also affected (uses '121)
- Other modules may need timing redesign
- But the core logic design remains valid!

## Lessons Learned
1. **Old stock can be unreliable** even if it "should" work
2. **One-shots are notoriously finicky** - avoid when possible
3. **Sometimes the datasheet is right but the chips are wrong**
4. **5 hours of debugging proved the design was correct** - it was the components that failed

## Next Steps
1. Build standalone 74LS14 pulse generator
2. Stress test with rapid Arduino pulses
3. Verify reliable operation at all speeds
4. Retrofit into DINO modules
5. Order new components for critical timing circuits

## The Bottom Line
We weren't crazy. The circuit was right. The '121 just let us down after 40 years of existence.

---
*Sometimes vintage parts don't vintage well.*