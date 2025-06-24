**Motorola 6808 Digital Thermometer - High Level Project Plan**

---

## Goal
Bring up a Motorola 6808 (or compatible variant) microprocessor and build a digital thermometer using a thermistor and ADC, displaying temperature on 7-segment displays. Program resides in ROM or ROM emulator; glue logic will interface with ADC and display latches.

---

## Milestone Phases

### Phase 1: Power and Clock
- Provide stable +5V regulated supply
- Clock input (typically 1 MHz–3 MHz)
  - Use TTL oscillator module or crystal + inverter

### Phase 2: Reset and Startup
- Simple RC circuit or Schmitt-trigger-based reset pulse
- Optionally debounce manual reset pushbutton

### Phase 3: Memory Map Setup
- Assign lower memory region to ROM (e.g., 0x0000–0x1FFF)
- Optional SRAM in upper memory if needed (e.g., 0x8000–0x87FF)
- Use 74LS138 for chip select decoding

### Phase 4: Peripheral Addressing
- Map ADC data register (e.g., 0xA000)
- Map control port for display output (e.g., 0xB000–0xB002)
- Use address decoding logic with A15..A12 for select lines

### Phase 5: Thermistor Interface
- Thermistor in voltage divider to ADC input
- Use ADC0804 or similar 8-bit ADC (start conversion + poll ready + read result)
- Glue logic:
  - Pulse START
  - Wait for INTR low
  - Read digital value from ADC output port

### Phase 6: Temperature Conversion
- Lookup table or linear approximation
- Convert ADC value to Celsius
- Break into individual BCD digits for display

### Phase 7: Output Display
- Three 7-segment displays for numeric output
- Use 74LS374 latches to hold segment values
- BCD → 7-segment decoder (e.g., 7447) or drive segments directly
- CPU writes each digit via OUT to latched port

---

## Notes
- 6808 has separate I/O space, simplifies glue logic
- Internal stack pointer and simpler timing than 8008
- Easier peripheral interfacing via full address/data separation
- Use NOPs for delay loops if needed for ADC timing

---

## Success Criteria
- CPU boots from ROM and runs without supervision
- Periodically reads thermistor and updates display
- Visible, stable temperature shown on 7-segment display

---

## Extensions and Future Projects
- Add serial output for remote logging
- Add buttons to set thresholds or max/min tracking
- Expand to multi-channel ADC and sensor cycling
- Store and recall historical values from SRAM
- Use piezo or buzzer for alarm condition output

