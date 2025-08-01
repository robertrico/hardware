# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is an embedded systems portfolio containing multiple hardware projects spanning discrete logic CPU design, microcontroller development, and wireless communication systems.

## Project Structure

### DINO CPU (Discrete Integrated NISC Operator)
- **Path**: `dino/`
- **Description**: Custom 8-bit CPU built from discrete logic components (74-series ICs)
- **Current Version**: v0.0.2 in schematic/design phase
- **Key Files**: 
  - Schematics: `dino/dino_v0_0_2/*.kicad_sch`
  - Test files: `dino/tests/` (DSL logic analyzer captures)
  - Documentation: `dino/docs/notes/`

### Earth Rover System
- **Path**: `earth_rover/`
- **Description**: Multi-MCU rover with wireless communication
- **Components**:
  - Motor control board (STM32L432KC + FreeRTOS)
  - ESP32-C3 transmitter/receiver modules
- **Key Features**: ESP-NOW protocol, SPI communication, TB6612FNG motor driver

### Raspberry Pi Pico Projects
- **Path**: `rpi_projects/`
- **Description**: Various Pico/Pico W projects including OTA systems, WiFi implementations
- **Notable Projects**:
  - PicoBook: MicroPython-based book display system
  - OTA firmware update systems
  - WiFi manager implementations

### STM32 Bare Metal Projects  
- **Path**: `stm32_projects/`
- **Description**: Low-level STM32F411 projects without HAL/frameworks

### ESP32 Projects
- **Path**: `esp_projects/`
- **Description**: ESP-IDF based projects for ESP32-C3

## Build Commands

### STM32 Projects (Earth Rover Motor Control Board)
```bash
# Navigate to project directory
cd earth_rover/motor_control_board/

# Source environment (defines build functions)
source env.sh

# Build project
build  # Equivalent to: cmake -S . -B build && cmake --build build

# Debug with GDB
debug  # Equivalent to: arm-none-eabi-gdb build/motor_control_board.elf

# Flash and monitor via OpenOCD
monitor  # Equivalent to: openocd -f interface/stlink.cfg -f target/stm32l4x.cfg
```

### ESP32 Projects (Transmitter/Receiver)
```bash
# Navigate to ESP32 project
cd earth_rover/transmitter/  # or earth_rover/receiver/

# Source environment (sets ESP_PORT and functions)
source env.sh

# Build
build  # Equivalent to: idf.py build

# Flash to device
flash  # Equivalent to: idf.py flash -p $ESP_PORT

# Monitor serial output
monitor  # Equivalent to: idf.py monitor -p $ESP_PORT

# Debug with GDB
debug  # Equivalent to: idf.py gdb -p $ESP_PORT
```

### Raspberry Pi Pico Projects
```bash
# Use provided flash scripts
cd rpi_projects/

# Flash any project (requires project.env with ELF_FILE variable)
./flash.sh

# Flash and detach from OpenOCD
./flash-and-detach.sh
```

## Key File Types

- **`.dsl`**: DSLogic analyzer capture files (binary format) - used for DINO CPU timing verification
- **`.kicad_*`**: KiCad schematic and PCB files
- **`env.sh`**: Project-specific environment setup with build/flash/debug functions
- **CMakeLists.txt**: Build configuration for STM32 and Pico projects
- **sdkconfig**: ESP-IDF project configuration

## Development Patterns

### STM32 Development
- Uses CMake with custom ARM GCC toolchain
- STM32CubeMX generated HAL code in subdirectories
- FreeRTOS integration for real-time applications
- OpenOCD for debugging and flashing

### ESP32 Development  
- ESP-IDF framework with CMake
- ESP-NOW for wireless communication
- Component-based architecture

### DINO CPU Development
- Discrete logic design using 74-series ICs
- Systematic modular testing approach (documented in testing strategy)
- Logic analyzer verification for timing analysis
- KiCad for schematic capture

## Testing Strategy

### DINO CPU
- Modular integration testing (Ring Counter → Memory → ALU → Control)
- Logic analyzer verification required for timing validation  
- Hardware-in-the-loop testing with real discrete components

### Embedded Systems
- Hardware bring-up with oscilloscope/logic analyzer
- Serial debugging and monitoring
- Real-time validation of communication protocols

## Important Notes

- Always source `env.sh` in project directories before building
- DINO CPU requires physical hardware testing - no simulation
- ESP32 projects require correct serial port configuration in `env.sh`
- STM32 projects use custom linker scripts and startup code
- Logic analyzer captures (`.dsl` files) are binary and project-specific