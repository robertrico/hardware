**Intel 8008 LED Blinker - High Level Project Plan**

---

## Goal

Bring up an Intel 8008 microprocessor and run a minimal program to blink LEDs, using hand-assembled instructions stored in an EEPROM or ROM emulator. All glue logic will be custom-built using discrete logic ICs.

---

## Milestone Phases

### Phase 1: Power and Clock

- Provide clean regulated +5V power
- Generate 2-phase non-overlapping clock (PHI1, PHI2)
  - Required for 8008 to function
  - Consider 2-phase generator with 74LS123 monostables or RC + inverter topology

### Phase 2: Reset and Ready Logic

- Manual or timer-based RESET generator
- READY input control to gate execution
- Optional: HALT indicator LED (based on CPU state)

### Phase 3: Bus and Latch Architecture

- 8008 has a multiplexed address/data bus (A/D0-A/D7)
- Use latches (e.g., 74LS373 or 74LS573) to demux:
  - Low address byte (A0-A7)
  - High address nibble (A8-A10)
  - Data bus (for memory I/O)
- Address latched on SYNC

### Phase 4: Memory Interface

- Interface to external ROM emulator or EEPROM
- Simple SRAM may be added for later experiments
- Use ALE/SYNC to latch address; control /RD and /WR timing

### Phase 5: Instruction Assembly and Programming

- Manually write small instruction sequence:
  - Load accumulator with a value
  - Output to port (for LED)
  - Jump to loop (create infinite toggle)
- Example (pseudo-asm):
  ```
  MVI A, 0xFF   ; All LEDs on
  OUT 0x01      ; Write to LED port
  MVI A, 0x00   ; All LEDs off
  OUT 0x01
  JMP 0x0000    ; Loop
  ```
- Assemble into hex manually and flash to EEPROM/ROM emulator

### Phase 6: Output Device

- Build simple output port from latch (e.g. 74LS374) at I/O address 0x01
- Connect to 8 LEDs through resistors
- Enable latch on 8008 /WR and I/O select decode

### Phase 7: Control Signal Decoding

- Decode address and control lines to produce:
  - Memory /ROMCS
  - I/O /WR latch enable
- Use 74LS138 or discrete gates for decode

---

## Notes

- 8008 has separate /MEMR, /MEMW, /IOR, /IOW signals, but with strict timing
- Instruction set is simpler than 8080; only 8-bit registers, limited stack
- No internal stack pointer; CALL/RET require external RAM stack support (can be ignored for LED blinker)
- Perfect use case: fixed-purpose embedded controller
- Safety tips: ensure +5V regulation, clean reset, and no floating lines to protect expensive vintage chips

---

## Success Criteria

- 8008 runs autonomously from power-on
- LEDs blink with \~1 Hz period
- ROM emulator makes testing and iteration fast

---

## Post-Blink Goals (Future)

- Add SRAM + stack support
- Build input port (e.g., DIP switches)
- Explore serial output or bit-banged USART
- Investigate whether SPI/I2C were supported externally during 8008 era (most likely not natively)
- Replace LED output with 7-segment display decoding

---

## Potential Projects and Extensions

- **Garage Thermometer**: Read thermistor via ADC, display temperature on three 7-segment displays. 8008 handles lookup/scaling, outputting segment codes.
- **Threshold Alarm**: Add DIP switch for threshold input. Trigger buzzer or relay if exceeded.
- **Multi-sensor Monitor**: Use analog multiplexer and scan several thermistors with one ADC.
- **Minimal CLI**: Bit-banged serial interface for status messages or config (ambitious but possible).
- **Static Data Logger**: Store temperature readings to SRAM and cycle through display.

