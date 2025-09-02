# DINO Project Status: Retired

**Date**: August 31, 2025  
**Project**: DINO (Discrete Integrated NISC Operator) - 8-bit CPU from discrete logic  
**Version**: v0.0.2  
**Status**: Project halted due to signal integrity issues at target frequency

---

## Project Overview

### Architecture
- 8-bit CPU built from 74LS series discrete logic ICs
- Von Neumann architecture with 16-bit addressing
- Microcode-based control using AT28C64B EEPROMs
- Target operating frequency: 250kHz

### Component Count (from BOM and implementation)
- 37+ logic ICs including:
  - 74LS163 (4-bit counter for ring counter)
  - 2× 74LS138 (3-to-8 decoders for T0-T15 states)
  - 4× 74LS138 (decoders for control word banks)
  - 74LS10 (triple 3-input NAND), 74LS00 (quad NAND for QD inversion)
  - 74LS373 (8-bit latches for registers)
  - 74LS245 (bus transceivers)
  - 74LS74 (dual D flip-flops), 74LS73 (JK flip-flop for reset)
  - 74LS193 (up/down counters for PC), 74LS590 (8-bit counters)
  - 74LS157 (quad 2-to-1 multiplexers)
  - 74LS244 (octal buffer for reset opcode 0x00)
  - 74F382N (4-bit ALUs - designed but not built)
  - 74LS121 (monostable for PULSE_REQ)
  - 74LS14 (Schmitt trigger replacement for 74LS121)
- 2× AT28C64B (8KB EEPROM) for 16-bit microcode
- AT28C256 (32KB EEPROM) for program storage
- 32KB SRAM for data storage
- NE555 timer for clock generation (48Hz measured)

---

## Technical Issues Summary

### Primary Failure Mode
System instability at 250kHz clock frequency. Initial testing at 48Hz with NE555 timer worked, but target frequency exposed:
- Signal crosstalk between enable lines and data bus (bits 2-7 specifically affected per test logs)
- Capacitive coupling through breadboard substrate (measured parasitic capacitance issues)
- Insufficient isolation between control and data paths
- Wire loop antenna effects in dense wiring areas
- 74LS121 monostable multivibrator intermittent triggering (~30% success rate per 121-let-down.md)

### Register Module Test Results (from test logs)
| Issue | Impact | Root Cause | Documentation |
|-------|--------|------------|---------------|
| Arduino D13 loading | False failures on bit 5 | Built-in LED on test pin | register-pass.md |
| Bit order reversal | Data corruption (D13=bit0, D6=bit7) | Wiring error in bus connections | test_register.c |
| Bus value retention | Invalid reads | Parasitic capacitance | register-pass.md |
| Enable line noise | Random bit flips | Crosstalk at transitions | control-lines-register.dsl |
| Physical constraints | Unable to isolate signals | Breadboard density limits | 121-let-down.md |
| Timing mismatch | 121 failure | 16ms delays vs µs hardware needs | register-pass.md |

### Design Limitations
- No controlled impedance paths
- Shared ground return paths
- Adjacent signal routing without shielding
- Power distribution inadequate for switching currents

---

## Completed Modules

### Validated Components (v0.0.1 and v0.0.2)
- **Ring Counter**: 74LS163 + 74LS138 + NE555 - T0-T15 states confirmed (ring-counter-16-state-test.dsl)
- **Program Counter**: Dual 74LS590 8-bit counters - 16-bit operation verified (pc-16-test-1.dsl)
- **555 Timer**: ~48Hz with R1=10kΩ, R2=10kΩ, C=1µF (555-standalone.dsl, dino_0_0_1_wiring_summary.md)
- **Bus Transceivers**: 74LS245 - Bidirectional operation verified (test_245_373.c)
- **Register Latches**: 74LS373 - Functional at low frequencies, tested with Arduino (test_373.c)
- **Instruction Register**: 74LS244 + 74LS373 combination tested (test_ir.c, 244_373_ir.dsl)
- **Control Timing**: 74LS121 - Eventually failed, replaced with 74LS14 + RC design

### Test Infrastructure Developed
- Arduino Uno bare-metal test framework (AVR-GCC, no Arduino IDE)
- Automated IC testing suite with LED indicators (TESTS.md)
- Clock generator with adjustable frequency (80kHz to 1.5MHz tested)
- Logic analyzer captures: 13 .dsl files documenting timing
- Build system: CMake + custom test scripts (run-build-test.sh)

### Test Coverage
- Low-frequency operation (48Hz): Fully functional
- Arduino test frequency (10µs delays): Mostly working
- Target frequency (250kHz): <40% stable operation
- Maximum tested: 1.5MHz with clock generator (clean pulses achieved)

---

## Development Timeline & Phases

### Phase 1: Core Timing Foundation (Completed)
- Ring counter with 74LS163 + 74LS138 + NE555
- Successfully expanded to full T0-T15 timing sequence
- 74LS138 Decoder #1: Active during T0-T7 (QD inverted)
- 74LS138 Decoder #2: Active during T8-T15 (QD direct)
- 60Hz operation validated with logic analyzer
- Documented in dino_0_0_1_wiring_summary.md

### Phase 2: Control Word Architecture (Completed)
- 16-bit control word structure fully designed and implemented
- Four decoder banks organized by function:
  - Bank 1 [2:0]: Register Operations (REG_A/B/C LOAD/OUT, MDR_LOAD)
  - Bank 2 [5:3]: Memory Operations (ROM/RAM OUT, MAR_LO/HI_LOAD)
  - Bank 3 [8:6]: Program Counter Control (PC_CLEAR, PC_PRESET, MDR_OUT)
  - Bank 4 [11:9]: ALU Operations (ADD, SUB, AND, OR, XOR, IR_LOAD)
- Additional control bits: HALT, MAR_PC_MUX, PC_UP, PULSE_REQ
- Instruction set implemented: LDAI, LDBI, STA, STB, NOP, LDA, ADD, MOV, OUT, HLT
- Test program developed validating complete fetch-decode-execute cycle

### Phase 3: Microcode Decoder Module (Completed)
- Dual AT28C64 8KB EEPROMs programmed for 16-bit control words
- 4 × 74LS138 decoders split control word into functional banks
- PULSE_REQ discovery: 74LS121 generates intra-phase timing for latches
- Boot sequence strategy: Addresses 0x0000-0x000F reserved
- Test programs (test.c, verify.c) written for EEPROM verification
- Static testing with multimeter confirmed correct microcode outputs
- GECU T48 programmer used for EEPROM burning

### Phase 4: Memory and Control Implementation (Completed)
- **Memory Data Register (MDR)**: Built and tested - temporary storage for memory operations
- **Instruction Register (IR)**: 74LS244 + 74LS373 combination fully operational
  - 74LS244 forces opcode 0x00 during reset
  - 74LS373 latches instruction from data bus
- **Memory Module**: SRAM and Program ROM fully implemented
  - AT28C256 (32KB) for program storage
  - 32KB SRAM for data storage
  - Address decoding and control logic operational
- Test programs validated memory read/write operations

### Phase 5: Register Module (Failed - Project Halted Here)
- **Register Module**: Where signal integrity collapsed
  - 74LS245 + 74LS373 + 74LS121 combination
  - Worked at low frequencies but failed at 250kHz
  - Crosstalk and parasitic effects made reliable operation impossible
  - This was the breaking point that led to project retirement

### Never Reached
- **ALU Integration**: 74F382N dual 4-bit ALUs - designed in KiCad but never built
- **Full System Integration**: Would have connected all modules via data bus
- **Complete CPU Testing**: Running full programs through fetch-decode-execute

---

## Technical Knowledge Acquired

### Instrumentation Skills
- **Logic analyzer**: DSLogic Plus used extensively
  - 20MHz sampling rate minimum required (found through debugging)
  - Protocol decoding for control signals
  - Glitch detection (found spurious 121 triggers)
  - 13 capture files documenting various modules
- **Oscilloscope**: 
  - Rise time: 30ns measured
  - Fall time: 84ns measured
  - 10X probe setting critical (initial error with 1X setting)
  - 330Ω series resistor improved signal clarity
- **Signal generator**: Arduino-based clock up to 1.5MHz tested

### Circuit Analysis
- Parasitic element identification and measurement
- Transmission line effects in digital circuits
- Ground bounce and return path analysis
- Decoupling capacitor placement optimization

### 74LS Series Characteristics (Learned from Testing)
- **74LS121 Issues**: Age-related degradation in 30-50 year old stock
  - Intermittent triggering across Signetics and TI chips
  - Internal capacitor leakage suspected
  - Replaced with 74LS14 Schmitt trigger + RC design
- **74LS590 Program Counter**: 
  - Both CCK and RCK require rising edge
  - RCO is brief pulse, not latched HIGH
  - Chaining via RCO to ~CE for multi-byte counting
- **74LS373 Latch**: 
  - LE HIGH = transparent, LOW = latched
  - Requires proper sequencing with bus transceivers
- **74LS245 Transceiver**:
  - DIR and ~OE coordination critical
  - Can share control with 373 ~OE (complementary logic)

---

## Requirements for Continuation

### Hardware Redesign
1. **PCB Implementation**
   - Multi-layer stackup with dedicated ground plane
   - Controlled impedance traces
   - Decoupling capacitor per IC
   - Proper ground plane

2. **Signal Routing**
   - Minimize trace lengths for high-speed signals
   - Consider differential pairs for critical signals
   - Guard traces between sensitive lines
   - Via stitching for return paths

3. **Power Distribution**
   - Bulk capacitance at power entry points
   - High-frequency bypass at each IC
   - Separate analog/digital supply rails where needed
   - Adequate current capacity for all components

### Alternative Approaches
- Reduce target frequency for breadboard compatibility
- Implement in FPGA for functional verification
- Use wire-wrap construction for better signal integrity
- Modular PCB approach with interconnect headers

---

## Project Metrics

### Code & Documentation
- **Test Programs**: 8 C source files in module_tests/src/
  - test_373.c, test_245_373.c, test_ir.c, test_register.c
  - test_pulse.c, clock.c, test_common.c
- **Logic Analyzer Captures**: 13 .dsl files across v0.0.1 and v0.0.2
- **Schematics**: 15 KiCad schematic files for v0.0.2 design
- **Documentation**: Multiple markdown files documenting wiring, testing strategy, issues

### Hardware Tested
- **ICs Validated**: 74LS163, 74LS138, 74LS10, 74LS373, 74LS245, 74LS244, 74LS121, 74LS590, NE555
- **Test Patterns**: 26 different patterns including walking bits, alternating bits, edge cases
- **Frequency Range**: 48Hz to 1.5MHz tested

### Key Technical Discoveries
- Breadboard frequency limit: ~50kHz for complex digital circuits
- Arduino D13 has built-in LED causing loading issues
- 74LS121 reliability issues with vintage stock
- Importance of proper probe settings (10X vs 1X)
- Critical timing: microseconds not milliseconds for hardware

---

## Conclusion

Project terminated during Phase 5 at the Register Module implementation. Successfully completed the microcode architecture, control word design, memory subsystems (MDR, IR, ROM, SRAM), but could not achieve reliable register operation at target frequency. The logical design was proven sound and most modules were physically built, but breadboard construction ultimately failed due to signal integrity issues.

### What Was Successfully Achieved

#### Theoretical & Design Work (Fully Completed)
- **16-state ring counter**: Expanded from T0-T5 to full T0-T15 implementation
- **16-bit control word matrix**: Complete microcode architecture with 4 decoder banks
- **Instruction set architecture**: 10 instructions with full timing sequences defined
- **Microcode programming**: Dual EEPROM configuration tested and verified
- **Boot sequence strategy**: Reset handling via 74LS244 and JK flip-flop design
- **Complete schematics**: All modules drafted in KiCad including MDR, IR, Memory, Registers

#### Physical Implementation (Modules Completed)
- **Ring counter**: Working at 60Hz with full T0-T15 states verified
- **Program counter**: Dual 74LS590 implementation tested
- **Microcode decoder**: Dual EEPROMs programmed and outputs verified
- **Memory Data Register (MDR)**: Fully built and operational
- **Instruction Register (IR)**: Complete with reset handling via 74LS244
- **Memory Module**: 32KB ROM + 32KB SRAM with address decoding working
- **Register modules**: Built but failed at target frequency (this killed the project)
- Arduino test framework with 8 test programs
- 13 logic analyzer captures documenting timing

### Why Physical Implementation Failed at Registers
- **Register module** was the critical failure point:
  - Signal integrity collapsed at 250kHz target frequency
  - Crosstalk between enable lines and data bus (bits 2-7 specifically)
  - 74LS121 reliability issues (30% success rate with vintage stock)
  - Breadboard parasitic capacitance and inductance dominated at this complexity level
- Earlier modules (MDR, IR, Memory) worked because:
  - Simpler signal paths
  - Less dense wiring
  - Fewer simultaneous switching signals
- Started testing at 48Hz, should have begun at target frequency
- Register module's complexity exceeded breadboard capabilities

### Engineering Achievements
- **Microcode methodology**: Systematic approach from instruction set to control words
- **PULSE_REQ innovation**: Discovered need for intra-phase timing pulses
- **Test infrastructure**: Comprehensive IC validation suite
- **Documentation**: Complete build notes, schematics, and test programs

### The Critical Insight
The project proved that discrete logic CPU design is theoretically sound and can be fully specified in microcode. More importantly, it demonstrated that there's a complexity threshold for breadboard construction - simpler modules like memory and control logic work fine, but the dense interconnections required for register banks and ALU integration exceed breadboard capabilities at any reasonable frequency. The successful implementation of MDR, IR, and Memory modules alongside the complete microcode architecture proves the design was correct. The Register module represented the tipping point where breadboard parasitic effects became insurmountable.

### Legacy
- Complete 8-bit CPU architecture with microcode specification
- Proven instruction set with timing sequences
- EEPROM programming tools (test.c, verify.c) for microcode
- Detailed failure analysis for future discrete logic projects
- Evidence that breadboards have a practical complexity limit - memory and control modules work, but register banks with multiple simultaneous bus operations fail
- Proof that incremental module testing can succeed until interconnection density exceeds the medium's capability

Project archived August 31, 2025, with complete documentation, microcode, schematics, and test suite for future reference or PCB implementation.