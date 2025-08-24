# Arduino IC Test Suite

This document describes the available IC tests and their wiring requirements.

## Test System Overview

Tests are built using a flag-based system:
```bash
./build_test.sh [test_name]    # Build specific test
make -C build flash             # Flash to Arduino
```

Press the reset button to run a test. Tests run once and halt.

## LED Indicators

All tests use the same LED status system:

| LED | Pin | Color | Meaning |
|-----|-----|-------|---------|
| D0 | PD0 | Red | Test FAILED (or default blink when no test) |
| D2 | PD2 | Green | Test PASSED (all patterns verified) |
| D3 | PD3 | Yellow | Test RUNNING (blinks during progress) |

### Status Sequence
1. **Startup**: 3 yellow flashes = test starting
2. **Running**: Yellow ON solid, blinks between patterns
3. **Complete**: Yellow OFF
4. **Result**: Green (PASS) or Red (FAIL) solid

---

## Test 1: 74LS373 Octal Latch

Tests an 8-bit transparent latch with 3-state outputs.

### Build & Flash
```bash
./build_test.sh 373
make -C build flash
```

### Wiring

| Arduino Pin | 74LS373 Pin | Signal | Description |
|-------------|-------------|---------|-------------|
| D4 | Pin 11 (LE) | Latch Enable | HIGH = transparent, LOW→HIGH = latch |
| D5 | Pin 1 (OE) | Output Enable | Active LOW |
| D6 | Pin 8 (Q7) | Data bit 7 | Bidirectional |
| D7 | Pin 7 (Q6) | Data bit 6 | Bidirectional |
| D8 | Pin 6 (Q5) | Data bit 5 | Bidirectional |
| D9 | Pin 5 (Q4) | Data bit 4 | Bidirectional |
| D10 | Pin 4 (Q3) | Data bit 3 | Bidirectional |
| D11 | Pin 3 (Q2) | Data bit 2 | Bidirectional |
| D12 | Pin 2 (Q1) | Data bit 1 | Bidirectional |
| D13 | Pin 19 (Q0) | Data bit 0 | Bidirectional |
| GND | Pin 10 | Ground | |
| 5V | Pin 20 | VCC | |

**Note**: Data pins D6-D13 connect to BOTH the D inputs (pins 3,4,7,8,13,14,17,18) AND Q outputs for bidirectional operation.

### Test Patterns
- All zeros (0x00)
- All ones (0xFF)
- Alternating bits (0xAA, 0x55)
- Walking ones (0x01, 0x02, 0x04...)
- Walking zeros (0xFE, 0xFD, 0xFB...)
- Edge cases (0x0F, 0xF0, 0x81, etc.)

### Test Sequence
1. Disable outputs (OE HIGH)
2. Drive data pattern on bus
3. Pulse LE to latch data
4. Release bus (high-Z)
5. Enable outputs (OE LOW)
6. Read back and verify
7. Check for floating pins with pull-ups

---

## Test 2: 74LS245 + 74LS373 Combined

Tests a bus transceiver (245) working with a latch (373) as a register/buffer system.

### Build & Flash
```bash
./build_test.sh 245_373
make -C build flash
```

### Wiring

#### Arduino Connections
| Arduino Pin | Signal | Description |
|-------------|---------|-------------|
| D0 | Red LED | Test failed indicator |
| D1 | 245 ~OE | 245 Output Enable (active LOW) |
| D2 | Green LED | Test passed indicator |
| D3 | Yellow LED | Test running indicator |
| D4 | 373 ~LE | 373 Latch Enable (active LOW) |
| D5 | 373 ~OE + 245 DIR | Shared control (see below) |
| D6-D13 | Data Bus D7-D0 | Connect to 245 A-side |

#### 74LS245 Connections
| 245 Pin | Connect To | Signal | Description |
|---------|------------|---------|-------------|
| Pin 1 | Arduino D5 | DIR | Direction (HIGH=A→B, LOW=B→A) |
| Pin 19 | Arduino D1 | ~OE | Output Enable (active LOW) |
| Pin 2 | Arduino D13 | A0 | A-side bit 0 |
| Pin 3 | Arduino D12 | A1 | A-side bit 1 |
| Pin 4 | Arduino D11 | A2 | A-side bit 2 |
| Pin 5 | Arduino D10 | A3 | A-side bit 3 |
| Pin 6 | Arduino D9 | A4 | A-side bit 4 |
| Pin 7 | Arduino D8 | A5 | A-side bit 5 |
| Pin 8 | Arduino D7 | A6 | A-side bit 6 |
| Pin 9 | Arduino D6 | A7 | A-side bit 7 |
| Pin 18 | 373 D0/Q0 | B0 | B-side bit 0 |
| Pin 17 | 373 D1/Q1 | B1 | B-side bit 1 |
| Pin 16 | 373 D2/Q2 | B2 | B-side bit 2 |
| Pin 15 | 373 D3/Q3 | B3 | B-side bit 3 |
| Pin 14 | 373 D4/Q4 | B4 | B-side bit 4 |
| Pin 13 | 373 D5/Q5 | B5 | B-side bit 5 |
| Pin 12 | 373 D6/Q6 | B6 | B-side bit 6 |
| Pin 11 | 373 D7/Q7 | B7 | B-side bit 7 |
| Pin 10 | GND | Ground | |
| Pin 20 | 5V | VCC | |

#### 74LS373 Connections
| 373 Pin | Connect To | Signal | Description |
|---------|------------|---------|-------------|
| Pin 11 | Arduino D4 | ~LE | Latch Enable (active LOW) |
| Pin 1 | Arduino D5 | ~OE | Output Enable (active LOW) |
| Pins 3,4,7,8,13,14,17,18 | 245 B-side | D0-D7 | Data inputs |
| Pins 2,5,6,9,12,15,16,19 | 245 B-side | Q0-Q7 | Data outputs (same nets) |
| Pin 10 | GND | Ground | |
| Pin 20 | 5V | VCC | |

### Control Logic

#### PD5 Shared Signal
Since 373 ~OE and 245 DIR are complementary:
- **PD5 HIGH**: 373 disabled (~OE=HIGH), 245 A→B (DIR=HIGH) - for writing
- **PD5 LOW**: 373 enabled (~OE=LOW), 245 B→A (DIR=LOW) - for reading

No inverter needed - wire PD5 directly to both pins.

### Data Flow

#### Write Path (Arduino → 373)
1. PD5 = HIGH (373 off, 245 A→B)
2. PD1 = LOW (245 enabled)
3. Arduino drives D6-D13
4. Data flows: Arduino → 245 A-side → 245 B-side → 373 inputs
5. Pulse PD4 LOW then HIGH to latch

#### Read Path (373 → Arduino)
1. PD5 = LOW (373 on, 245 B→A)
2. PD1 = LOW (245 enabled)
3. Data flows: 373 outputs → 245 B-side → 245 A-side → Arduino
4. Arduino reads D6-D13

### Test Features
- Same 26 test patterns as 373 test
- Verifies bidirectional data flow through 245
- Tests direction control switching
- Detects floating/disconnected lines
- Ensures no bus contention

---

## Adding New Tests

1. Create test files:
   ```c
   // test_xxx.h
   void test_xxx_run(void);
   
   // test_xxx.c
   #include "test_xxx.h"
   void test_xxx_run(void) {
       // Test implementation
   }
   ```

2. Update `main.c`:
   ```c
   #ifdef TEST_XXX
       #include "test_xxx.h"
   #endif
   
   // In main():
   #elif defined(TEST_XXX)
       test_xxx_run();
   ```

3. Update `CMakeLists.txt`:
   ```cmake
   elseif(TEST_TYPE STREQUAL "xxx")
       add_definitions(-DTEST_XXX)
       list(APPEND SOURCES test_xxx.c)
       message(STATUS "Building xxx test")
   ```

4. Build and test:
   ```bash
   ./build_test.sh xxx
   make -C build flash
   ```

## Troubleshooting

### No LEDs Light Up
- Check 5V and GND connections
- Verify Arduino is powered
- Try default test: `./build_test.sh && make -C build flash`

### Red LED Blinking (No Test)
- This is the default mode
- Build a specific test: `./build_test.sh 373`

### Test Fails (Red LED Solid)
- Check all connections match wiring diagram
- Verify IC orientation (pin 1 marker)
- Test with known good IC
- Check for bent pins or bad breadboard connections

### Yellow LED Stays On
- Test may be stuck
- Check data bus connections
- Verify control signals are connected correctly

### Floating Pin Detection
- Test checks for disconnected pins using pull-ups
- Even if data accidentally matches, floating pins are detected
- Ensures robust connection verification