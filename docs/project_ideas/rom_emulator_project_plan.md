# EEPROM Emulator & Burner Development Plan

## Overview

A progressive hardware/software roadmap for building EEPROM emulation and programming systems using the RP2040. The plan evolves from a basic read-only ROM emulator using GPIO to a full-featured PIO-based EEPROM emulator and writer. Each step builds on skills and infrastructure developed in the prior phase.

---

## Phase 1: GPIO Read-Only ROM Emulator

**Goal**: Simulate a 28C256-compatible ROM using GPIO only (no PIO), serving data from a const `rom_data[]` array in flash.

### Features:

- Address input via GPIO 0–14
- /CE and /OE detection via GPIO 15 and 14
- Data output on GPIO 16–23
- Tri-state control based on CE/OE state
- ROM contents compiled into flash

### Milestones:

- Validate behavior with logic analyzer
- Match 28C256 timing expectations (e.g., address setup, output enable)
- Optional ROM bank switching via GPIO jumpers

---

## Phase 2: GPIO Bi-Directional EEPROM Emulator

**Goal**: Extend the ROM emulator to support simulated writes (read/write bus behavior) using full bidirectional data handling.

### Features:

- Detect /WE pulses
- Read data from D0–D7 during write
- Write to RAM-backed `eeprom_data[]` buffer
- Respond to reads from `eeprom_data[]`
- GPIO pinmode switching between input/output dynamically

### Milestones:

- Pass real write + read-back tests using sequencer
- Implement clear-on-reset or RAM prefill pattern
- Track bus contention / hold timing

---

## Phase 3: PIO Bi-Directional EEPROM Emulator

**Goal**: Replace GPIO logic with a PIO-based protocol engine for deterministic, clean timing.

### Features:

- PIO handles /CE, /OE, /WE edge detection
- PIO reads address bus and pushes to CPU
- PIO reads or drives D0–D7
- CPU serves reads or captures writes via FIFO

### Milestones:

- 100% cycle-valid signal verification via logic analyzer
- Match or exceed 28C256 spec timing
- Bus-safe tri-state handling
- Optional DMA preload or write logging

---

## Phase 4: Full PIO EEPROM Burner

**Goal**: Build a write-only tool using PIO to interface with a physical 28C256 EEPROM chip to program it directly.

### Features:

- Parallel address + data output
- /WE pulsing via PIO or GPIO
- Setup/hold/write timing guaranteed via cycle counting or dividers
- ROM image loaded from flash or USB

### Milestones:

- Program 28C256 successfully and verify content
- Add ROM verify step post-write
- Optional: Support multiple burner modes (page, single-byte)
- Optional: USB CLI or host interface to feed new images

---
