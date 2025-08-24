# 245+373 Test Wiring Verification Checklist

## Pre-Flight Checks

### Power Connections
- [ ] 245 Pin 20 (VCC) → 5V
- [ ] 245 Pin 10 (GND) → GND
- [ ] 373 Pin 20 (VCC) → 5V
- [ ] 373 Pin 10 (GND) → GND
- [ ] Both ICs have bypass capacitors (0.1µF) between VCC and GND

### IC Orientation
- [ ] 245 Pin 1 (DIR) is at the notch/dot end
- [ ] 373 Pin 1 (~OE) is at the notch/dot end
- [ ] Both ICs are inserted fully into breadboard

## Control Signal Wiring

### Critical D5 Connection (MUST be connected to BOTH)
- [ ] Arduino D5 → 245 Pin 1 (DIR)
- [ ] Arduino D5 → 373 Pin 1 (~OE)
- [ ] Verify with continuity: D5 reaches both IC pins

### Other Control Signals
- [ ] Arduino D1 → 245 Pin 19 (~OE)
- [ ] Arduino D4 → 373 Pin 11 (~LE)

## Data Bus Connections

### Arduino to 245 A-Side (CRITICAL - Arduino connects to A-side!)
- [ ] Arduino D13 → 245 Pin 2 (A0)
- [ ] Arduino D12 → 245 Pin 3 (A1)
- [ ] Arduino D11 → 245 Pin 4 (A2)
- [ ] Arduino D10 → 245 Pin 5 (A3)
- [ ] Arduino D9 → 245 Pin 6 (A4)
- [ ] Arduino D8 → 245 Pin 7 (A5)
- [ ] Arduino D7 → 245 Pin 8 (A6)
- [ ] Arduino D6 → 245 Pin 9 (A7)

### 245 B-Side to 373 (Each B pin connects to BOTH D and Q pins)
- [ ] 245 Pin 18 (B0) → 373 Pin 3 (D0) AND Pin 2 (Q0)
- [ ] 245 Pin 17 (B1) → 373 Pin 4 (D1) AND Pin 5 (Q1)
- [ ] 245 Pin 16 (B2) → 373 Pin 7 (D2) AND Pin 6 (Q2)
- [ ] 245 Pin 15 (B3) → 373 Pin 8 (D3) AND Pin 9 (Q3)
- [ ] 245 Pin 14 (B4) → 373 Pin 13 (D4) AND Pin 12 (Q4)
- [ ] 245 Pin 13 (B5) → 373 Pin 14 (D5) AND Pin 15 (Q5)
- [ ] 245 Pin 12 (B6) → 373 Pin 17 (D6) AND Pin 16 (Q6)
- [ ] 245 Pin 11 (B7) → 373 Pin 18 (D7) AND Pin 19 (Q7)

## LED Connections
- [ ] Arduino D0 → Red LED → 220Ω resistor → GND
- [ ] Arduino D2 → Green LED → 220Ω resistor → GND
- [ ] Arduino D3 → Yellow LED → 220Ω resistor → GND

## Common Problems to Check

### If Test Always Fails
1. **A/B Sides Swapped**: Arduino MUST connect to 245 A-side (pins 2-9)
2. **Missing D5 Connection**: D5 must go to BOTH 245 pin 1 AND 373 pin 1
3. **Wrong Data Order**: D13 is bit 0, D6 is bit 7 (reversed)
4. **Floating Pins**: Check all 8 data connections Arduino→245→373

### If Random Failures
1. **Bad Breadboard Row**: Try moving ICs to different rows
2. **Loose Jumper Wire**: Wiggle each wire while checking continuity
3. **Power Issues**: Add capacitors, check 5V is stable
4. **Timing Issues**: ICs might be slower than expected

### If Specific Patterns Fail
1. **0x00 fails**: Check for stuck-high bits (short to VCC)
2. **0xFF fails**: Check for stuck-low bits (short to GND)
3. **0xAA/0x55 fail**: Check for adjacent pin shorts
4. **Walking bits fail**: Specific pin not connected

## Signal Flow Verification

### Write Operation (Arduino → 373)
1. D5 = HIGH (373 disabled, 245 A→B)
2. D1 = LOW (245 enabled)
3. Arduino outputs data on D6-D13
4. Data flows: Arduino → 245 A → 245 B → 373 D inputs
5. D4 pulses LOW then HIGH (latches data)

### Read Operation (373 → Arduino)
1. D5 = LOW (373 enabled, 245 B→A)
2. D1 = LOW (245 enabled)
3. Data flows: 373 Q → 245 B → 245 A → Arduino
4. Arduino reads D6-D13

## Debug Strategy

### Step 1: Test 373 Alone
Run test: `./build_test.sh 373`
- If this fails, fix 373 wiring first

### Step 2: Check 245 Direction
With 245+373 test:
1. Set D5 HIGH (A→B mode)
2. Set D1 LOW (245 enabled)
3. Drive pattern on Arduino pins
4. Check pattern appears on 245 B-side with multimeter

### Step 3: Check Full Path
1. Run full test
2. If fails, check each signal with oscilloscope/logic analyzer
3. Verify timing of LE pulse and direction changes

## Quick Voltage Checks (with test running)

During Write Phase (D5=HIGH):
- 245 Pin 1 (DIR) = 5V
- 373 Pin 1 (~OE) = 5V
- 245 Pin 19 (~OE) = 0V (enabled)

During Read Phase (D5=LOW):
- 245 Pin 1 (DIR) = 0V
- 373 Pin 1 (~OE) = 0V
- 245 Pin 19 (~OE) = 0V (enabled)

During Latch Pulse:
- 373 Pin 11 (~LE) = 0V briefly, then 5V

## Notes
- The 245 A-side MUST connect to Arduino
- The 245 B-side MUST connect to 373
- D5 MUST connect to both ICs
- Data bus bit 0 is on D13, not D6!