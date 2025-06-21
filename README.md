# Embedded Systems Portfolio

Welcome to my Embedded Systems Portfolio. This document introduces several projects, highlighting their objectives, technologies, and current status.

---

## LED Blinky Projects

#### Zephyr RTOS Blinky on Raspberry Pi Pico

* **Objective**: GPIO control demonstration using Zephyr RTOS.
* **Technologies**: Raspberry Pi Pico, Zephyr RTOS, DeviceTree.
* **Current Status**: Complete.

#### FreeRTOS LED Blinky for Pico W, Pico W2, ESP32

* **Objective**: Basic FreeRTOS demonstration with task scheduling and GPIO control.
* **Technologies**: FreeRTOS, Raspberry Pi Pico W, Pico W2, ESP32.
* **Current Status**: Complete

## PicoBook

* **Objective**: A compact device fetching and displaying book data via Wi-Fi.
* **Technologies**: Raspberry Pi Pico W, MicroPython, OLED display, Wi-Fi.
* **Current Status**: Complete.

## Zephyr OS "Hello World" on Raspberry Pi Pico

* **Objective**: Minimal Zephyr OS application printing to USB serial.
* **Technologies**: Zephyr OS, RP2040.
* **Current Status**: Complete

## PicoW Over-The-Air (OTA) Firmware System

* **Objective**: Dual-partition bootloader enabling OTA firmware updates.
* **Technologies**: RP2040, pico-sdk, assembly, linker scripts.
* **Current Status**: Complete - But inoperable. There were struggles with the bootloader and ROM and highlighted knowledge gaps. This work was the catalyst for a full re-understanding of low level work. Inspiring the DINO project.

## ESP-NOW Remote Control Project

* **Objective**: Wireless remote control for toggling LEDs using ESP-NOW protocol.
* **Technologies**: ESP32-C3, ESP-IDF, ESP-NOW.
* **Current Status**: Complete

## The Earth Rover

* **Objective**: Modular rover system using ESP-NOW and STM32 for real-time motor control and wireless ADC data transmission.
* **Technologies**: ESP32-C3, STM32L432KC, ESP-NOW, FreeRTOS, STM32CubeMX, CMake, SPI, DMA, TB6612FNG, CD4053BE.
* **Current Status**: Communication functional; currently refining SPI packetization and synchronization.

## Dino (Discrete Integrated NISC Operator) CPU

#### Dino v0.01 – Manual Logic Sequencer

* **Objective**: CPU-free logic sequencer manually steps through memory and outputs 8-bit values via LEDs.
* **Technologies**: SN74LS590N counters, 555 timer, SRAM, DIP switches, LEDs.
* **Current Status**: In Progress. Schematic Phase.

#### Dino v0.1 – 8-bit CPU Core

* **Objective**: Upgrade to a functional 8-bit CPU with ALU, registers, and basic arithmetic operations.
* **Technologies**: 74F382N ALU, SN74LS273N registers, DM74LS374 latch.
* **Current Status**: Planned

#### Dino v0.1.1 – Instruction Decoder & 7-Segment Display

* **Objective**: Adds instruction decoding and output display.
* **Technologies**: SN74LS138N decoder, 7-segment display drivers.
* **Current Status**: Planned
