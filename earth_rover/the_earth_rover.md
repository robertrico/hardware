# The Earth Rover

## Overview

**The** **Earth Rover** project is a robust, modular, and extensible embedded rover system, leveraging proven technology and workflows from previous embedded projects. It integrates wireless communication, real-time control, and precision motor control for reliable and scalable rover operations.

## System Architecture

### Communication Layer

* **ESP-NOW Protocol**:

  * Utilizes two ESP32-C3 devices (`TX` and `RX`).
  * Transmits 12-bit ADC values (0-4095) captured from joystick potentiometers.
  * Data is converted to Little Endian (LSB-first) for accurate transmission and decoding.
  * Implements a CD4053BE analog multiplexer to expand ADC inputs from 3 to 5.
  * ESP-IDF and CMake under VSCode environment streamline firmware development.

### Motor Control Board (MCB)

* **MCU**: STM32L432KC

  * Firmware and initialization generated using STM32CubeMX and CMake.
  * Development and debugging facilitated by OpenOCD and ARM GDB.

* **Motor Drivers**:

  * Two TB6612FNG dual motor drivers for precise bidirectional motor control.

* **FreeRTOS Integration**:

  * Unified development pattern with ESP32-C3’s native FreeRTOS.
  * Ensures seamless multitasking and future extensibility.

### Communication Interface (SPI)

* **RX Device** acts as SPI master.
* **STM32 MCB** configured as full-duplex SPI slave.
* Data transmission leverages DMA to ensure minimal latency and mitigate buffer overflow issues.
* Logic analyzer (DSL) extensively used to validate data flow and debug SPI transactions.

### Key Technical Findings and Solutions

* **ADC Expansion**:

  * Resolved ESP32-C3 ADC limitations using CD4053BE Multiplexer.
  * Cycles through MUX inputs efficiently, transmitting accurate, ordered values via ESP-NOW.

* **IDE and Workflow Optimization**:

  * Initially tested STM32CubeIDE; determined it created friction with existing workflows.
  * Shifted to STM32CubeMX for initial code generation, integrated seamlessly into VIM-based CMake workflow.

* **ESP-NOW Stability and Performance**:

  * Addressed data transmission overflow by using one-shot mode instead of continuous mode.
  * Confirmed through logic analyzer and validated ADC value integrity at RX endpoint.

* **SPI DMA Challenges and Solutions**:

  * DMA implemented successfully on STM32, overcoming data overflow issues.
  * Current efforts are focused on packetization and synchronization to resolve misaligned data receptions.
  * Packet headers (`0x1234`) established to clearly delineate and verify valid data packets.
  * Chip Select (CS) manually controlled via STM32 External Interrupts (EXTI) to precisely align and control data transmission.

* **Deadband Implementation**:

  * Prevents unnecessary data transmission and reduces communication overhead.

## Current Status and Next Steps

* ESP-NOW and ADC multiplexing fully functional.
* STM32 SPI communication operational; refinement of packet handling and synchronization in progress.
* Packetization strategy and manual CS implementation actively being developed and tested.
* Continuing iterative testing with logic analyzers and ARM GDB debugging.
