# FPGA Learning Projects - Progressive Path to FSM Mastery

This document outlines a series of progressively complex projects that build fundamental FPGA skills, culminating in a comprehensive Finite State Machine (FSM) project using buttons and LEDs.

---

## Project 1: Single LED Blinker ✅ COMPLETE
**Status**: Complete (current project)

**Concepts Learned**:
- Basic VHDL structure (entity, architecture)
- Clock domain logic
- Counter implementation
- Process blocks
- Signal assignments
- Synthesis and place-and-route workflow

**Hardware Used**:
- 1 LED
- Clock input

**Next Step**: Learn about multiple outputs and patterns

---

## Project 2: LED Knight Rider / Cylon Scanner ✅ COMPLETE
**Difficulty**: ⭐⭐☆☆☆

**Description**:
Create a "Knight Rider" style LED pattern where a single LED moves left-to-right, then right-to-left across the 8 LEDs.

**New Concepts**:
- State machines (your first FSM!)
- Array/vector manipulation
- Direction control
- Case statements in VHDL

**Hardware Used**:
- 8 LEDs
- Clock input

**Implementation Hints**:
```vhdl
-- States: MOVING_RIGHT, MOVING_LEFT
-- Counter tracks which LED (0-7)
-- Pattern: 00000001 -> 00000010 -> 00000100 -> ... -> 10000000 -> (reverse)
```

**Skills Gained**:
- Basic 2-state FSM
- Sequential LED control
- Edge detection (when to change direction)

---

## Project 3: Binary Counter Display ✅ COMPLETE
**Difficulty**: ⭐⭐☆☆☆

**Description**:
Display an 8-bit binary counter on the 8 LEDs, incrementing once per second.

**New Concepts**:
- Binary number representation in hardware
- Integer to std_logic_vector conversion
- Overflow handling
- Time-based event triggering

**Hardware Used**:
- 8 LEDs (as binary digits)
- Clock input

**Implementation Hints**:
```vhdl
-- Count from 0 to 255 (8-bit)
-- Display each bit on an LED
-- Roll over from 255 to 0
```

**Skills Gained**:
- Working with binary numbers
- Type conversions in VHDL
- Understanding bit positions

---

## Project 4: Button-Controlled LED ✅ COMPLETE
**Difficulty**: ⭐⭐☆☆☆

**Description**:
Use a push button to toggle an LED on/off. Press once = ON, press again = OFF.

**New Concepts**:
- **Button debouncing** (critical!)
- Edge detection (rising edge of button press)
- Synchronization across clock domains
- Toggle logic

**Hardware Used**:
- 1 LED
- 1 Push button
- Clock input

**Implementation Hints**:
```vhdl
-- Button inputs are NOISY - need debouncing!
-- Detect rising edge: button_prev = '0' AND button_current = '1'
-- Debounce: sample button after it's been stable for ~10ms
```

**Skills Gained**:
- Critical real-world skill: debouncing
- Edge detection patterns
- State persistence (remembering LED state)

---

## Project 5: Multi-Button LED Control ✅ COMPLETE
**Difficulty**: ⭐⭐⭐☆☆

**Description**:
Control 4 LEDs with 4 buttons. Each button toggles its corresponding LED independently.

**New Concepts**:
- Multiple independent inputs
- Parallel button debouncing
- For-generate loops in VHDL
- Component instantiation

**Hardware Used**:
- 4 LEDs
- 4 Push buttons
- Clock input

**Implementation Hints**:
```vhdl
-- Create a reusable debounce component
-- Instantiate 4 debounce instances (one per button)
-- Each button controls one LED independently
```

**Skills Gained**:
- Modular design (components)
- Code reuse
- Scalable architectures

---

## Project 6: LED Pattern Sequencer ✅ COMPLETE
**Difficulty**: ⭐⭐⭐☆☆

**Description**:
Create multiple LED patterns (blink all, chase, alternate, etc.). One button cycles through patterns, another controls speed.

**New Concepts**:
- Multi-state FSM (4-5 states)
- Pattern generation
- Variable timing control
- Multiple buttons with different functions

**Hardware Used**:
- 8 LEDs
- 2 Push buttons (pattern select, speed control)
- Clock input

**Implementation Hints**:
```vhdl
-- States: PATTERN_BLINK, PATTERN_CHASE, PATTERN_ALTERNATE, PATTERN_RANDOM
-- Button1: cycles through patterns
-- Button2: toggles between FAST/SLOW speed
```

**Skills Gained**:
- More complex FSM design
- Multiple simultaneous state variables
- Parameter control (speed adjustment)

---

## Project 7: Simple Combination Lock 🚧 In Progress
**Difficulty**: ⭐⭐⭐⭐☆

**Description**:
Create a 4-button combination lock. User must press buttons in correct sequence (e.g., B1-B3-B2-B4) to "unlock" (turn green LED on). Wrong sequence turns red LED on and resets.

**New Concepts**:
- Sequential state machines
- Success/failure paths
- Timeout logic
- Multiple output conditions

**Hardware Used**:
- 2 LEDs (green = unlocked, red = error)
- 4 Push buttons
- Clock input

**State Machine**:
```
IDLE -> WAIT_B1 -> WAIT_B3 -> WAIT_B2 -> WAIT_B4 -> UNLOCKED
       ↓ (wrong)  ↓ (wrong)  ↓ (wrong)  ↓ (wrong)
       ERROR -----+----------+----------+----------+
```

**Skills Gained**:
- Sequential logic
- Success/failure handling
- Timeout implementation
- Security-like state machines

---

## Project 8: Reaction Time Game
**Difficulty**: ⭐⭐⭐⭐☆

**Description**:
Game: Random LED lights up after a delay. Player must press corresponding button as fast as possible. Display reaction time using LED brightness or pattern.

**New Concepts**:
- Pseudo-random number generation (LFSR)
- Time measurement
- Game state machine
- Performance feedback

**Hardware Used**:
- 4 LEDs
- 4 Push buttons
- Clock input

**State Machine**:
```
IDLE -> COUNTDOWN -> WAIT_RANDOM -> LED_ON -> MEASURE_TIME -> DISPLAY_RESULT -> IDLE
```

**Skills Gained**:
- Random number generation in hardware
- Precise timing measurement
- Game logic implementation
- User feedback

---

## Project 9: Simon Says Memory Game
**Difficulty**: ⭐⭐⭐⭐⭐

**Description**:
Classic Simon Says game. Device plays a sequence of LED flashes. Player must repeat the sequence by pressing corresponding buttons. Sequence gets longer each round.

**New Concepts**:
- Memory storage (sequence buffer)
- Playback vs. record states
- Sequence comparison
- Progressive difficulty
- Score tracking

**Hardware Used**:
- 4 LEDs (different colors)
- 4 Push buttons
- Clock input

**State Machine**:
```
IDLE -> SHOW_SEQUENCE -> WAIT_USER_INPUT -> VERIFY_INPUT -> [SUCCESS/FAIL]
  ↑         ↓ (each LED in sequence)           ↓ (each button press)
  |         +---------------------------------+
  +--- (if correct, add to sequence)
```

**Features**:
- Store sequence in array/FIFO
- Playback sequence (light each LED with timing)
- Record user button presses
- Compare sequences
- Win condition (reach length 10?)
- Lose condition (wrong button)
- Display level using LED patterns

**Skills Gained**:
- Complex state machines
- Memory/storage in FPGA
- Sequence generation and storage
- Complex comparison logic
- Full game loop implementation

---

## Final Project: Traffic Light Controller with Pedestrian Crossing
**Difficulty**: ⭐⭐⭐⭐⭐

**Description**:
Full traffic light system controlling two intersections (North-South, East-West) with pedestrian crossing request buttons and walk signals.

**Complete System Features**:

### Hardware Required:
- 6 LEDs for vehicle lights:
  - 3 for N-S (Red, Yellow, Green)
  - 3 for E-W (Red, Yellow, Green)
- 2 LEDs for pedestrian walk signals
- 2 Push buttons (pedestrian crossing requests)
- Clock input

### State Machine:
```
NS_GREEN_EW_RED -> NS_YELLOW_EW_RED -> NS_RED_EW_RED_DELAY -> EW_GREEN_NS_RED ->
EW_YELLOW_NS_RED -> NS_RED_EW_RED_DELAY -> (loop)

    + Pedestrian states (can interrupt):
      PED_NS_WALK -> PED_NS_FLASH -> back to vehicle cycle
      PED_EW_WALK -> PED_EW_FLASH -> back to vehicle cycle
```

### Complex Features:
1. **Normal Operation**: Cycle through standard traffic light sequence
2. **Pedestrian Requests**:
   - Button press queues a request
   - Wait for safe time to enter pedestrian cycle
   - Display walk signal for ~10 seconds
   - Flash walk signal for ~5 seconds (warning)
   - Return to normal cycle
3. **Safety Delays**:
   - All-red period between transitions (1-2 seconds)
   - Minimum green time (can't change too fast)
   - Maximum green time (can't stay green forever if no cross traffic)
4. **Emergency Mode** (optional):
   - Hold both buttons = all lights flash red
5. **Night Mode** (optional):
   - Based on time counter, switch to flashing yellow

### Skills Gained:
- **Complex multi-state FSM** (10+ states)
- **Priority handling** (pedestrian interrupts)
- **Safety-critical timing** (all-red periods)
- **Event queueing** (button press while in wrong state)
- **Multiple concurrent timers**
- **Real-world system design**

### Implementation Challenges:
```vhdl
-- State enumeration with many states
-- Multiple timers (green time, yellow time, walk time, flash time)
-- Request flags (ped_ns_requested, ped_ew_requested)
-- Safety interlocks (never allow both directions green!)
-- Minimum/maximum time enforcement
```

---

## Progression Summary

| Project | LEDs | Buttons | States | Key Skill |
|---------|------|---------|--------|-----------|
| 1. Blinker | 1 | 0 | 1 | Basic VHDL, counters |
| 2. Knight Rider | 8 | 0 | 2 | First FSM, direction control |
| 3. Binary Counter | 8 | 0 | 1 | Binary representation |
| 4. Button Toggle | 1 | 1 | 2 | Debouncing, edge detection |
| 5. Multi-Button | 4 | 4 | 4 | Components, modularity |
| 6. Pattern Sequencer | 8 | 2 | 5 | Multi-state FSM |
| 7. Combination Lock | 2 | 4 | 7 | Sequential logic |
| 8. Reaction Game | 4 | 4 | 6 | Timing, randomness |
| 9. Simon Says | 4 | 4 | 8 | Memory, complex FSM |
| 10. Traffic Light | 8 | 2 | 12+ | Real-world system |

---

## Recommended Order

**Week 1-2**: Projects 1-3 (Master outputs and basic FSM)
**Week 3**: Project 4 (Critical: learn debouncing!)
**Week 4**: Projects 5-6 (Build FSM confidence)
**Week 5-6**: Projects 7-8 (Complex logic)
**Week 7-8**: Project 9 (Major challenge)
**Week 9-10**: Project 10 (Final comprehensive project)

---

## Common Concepts You'll Master

By completing all projects, you'll be proficient in:

### VHDL Skills:
- ✅ Entities and architectures
- ✅ Processes and sensitivity lists
- ✅ Signals vs. variables
- ✅ std_logic and std_logic_vector
- ✅ Integer and type conversions
- ✅ Case statements
- ✅ If-elsif-else chains
- ✅ For loops and generate statements
- ✅ Component instantiation
- ✅ Generic parameters

### Hardware Skills:
- ✅ Clock domain synchronization
- ✅ Edge detection
- ✅ Debouncing (mechanical switches)
- ✅ State machine design
- ✅ Counter design
- ✅ Timing and delays
- ✅ Resource optimization
- ✅ Safety interlocks

### Design Skills:
- ✅ Modular design
- ✅ Reusable components
- ✅ State machine documentation
- ✅ Testbench writing
- ✅ Simulation and verification
- ✅ Real hardware debugging

---

## Notes

- Each project should include:
  - Complete VHDL source code
  - Comprehensive testbench
  - Pin constraint file (.lpf)
  - README with state diagrams
  - Simulation waveforms

- Before moving to the next project:
  - Simulate and verify behavior
  - Synthesize and check resource usage
  - Test on actual hardware
  - Document any issues/learnings

- Keep all projects in separate directories:
  ```
  fpga/
    blinky/           (Project 1) ✅
    knight_rider/     (Project 2)
    external_components/   (Project 3)
    button_toggle/    (Project 4)
    ...
  ```

---

## Resources You'll Need

- **Lattice ECP5-5G Versa Development Kit** (you have this!)
- **8 LEDs** - already on board ✅
- **Buttons** - DIP switches or push buttons on board
- **Documentation**: Keep state diagrams for each FSM
- **Lab notebook**: Document issues and solutions

---

## Ready to Start?

Current status: **Project 1 Complete** ✅

Next recommended project: **Project 2: Knight Rider**
- Simple 2-state FSM
- Builds on your counter skills
- Introduces directional control
- Very visual and satisfying result!

Would you like to start on Project 2?
