# CLAUDE.md - Arduino Uno Development Guide

This file provides guidance to Claude Code when working with Arduino Uno development in this directory.

## Project Overview

This is a bare-metal Arduino Uno (ATmega328P) development environment using AVR-GCC toolchain without the Arduino IDE or framework. Direct register manipulation provides full control over the microcontroller.

## Hardware Specifications

- **MCU**: ATmega328P
- **Clock**: 16MHz crystal oscillator
- **Flash**: 32KB
- **SRAM**: 2KB
- **EEPROM**: 1KB
- **Digital I/O**: 14 pins (D0-D13)
  - D0 (PD0) - RX UART
  - D1 (PD1) - TX UART
  - D2 (PD2) - INT0
  - D3 (PD3) - INT1/PWM
  - D4 (PD4)
  - D5 (PD5) - PWM
  - D6 (PD6) - PWM
  - D7 (PD7)
  - D8 (PB0)
  - D9 (PB1) - PWM
  - D10 (PB2) - PWM/SS
  - D11 (PB3) - PWM/MOSI
  - D12 (PB4) - MISO
  - D13 (PB5) - SCK/Built-in LED
- **Analog Inputs**: 6 pins (A0-A5 on PC0-PC5)

## Build System

### Required Tools
- AVR-GCC toolchain (avr-gcc, avr-objcopy, avr-size)
- AVRDUDE for flashing
- CMake for build configuration
- Make for build execution

### Build Commands

```bash
# Initial CMake configuration (only needed once or after CMakeLists.txt changes)
cmake -S . -B build

# Build the project
make -C build

# Or simply from build directory
cd build && make
```

### Flash Commands

```bash
# Flash to Arduino Uno (from build directory)
cd build && make flash

# Or directly from project root
make -C build flash
```

The flash target automatically:
1. Builds the project if needed
2. Generates the .hex file
3. Uses AVRDUDE to upload to Arduino Uno via USB
4. Verifies the flash write

### Clean Build

```bash
# Clean build artifacts
make -C build clean

# Full rebuild
rm -rf build && cmake -S . -B build && make -C build
```

## Project Files

- `main.c` - Main source code file
- `CMakeLists.txt` - CMake build configuration
- `toolchain-avr.cmake` - AVR toolchain configuration
- `build/` - Build directory (generated)
- `build/blink.elf` - Compiled ELF binary
- `build/blink.hex` - Intel HEX format for flashing

## Programming Guidelines

### Register Access
Use direct register manipulation for hardware control:

```c
#include <avr/io.h>

// Set pin as output (Data Direction Register)
DDRD |= (1 << PD2);   // D2 as output
DDRB |= (1 << PB5);   // D13 as output

// Set pin high
PORTD |= (1 << PD2);  // D2 high

// Set pin low  
PORTD &= ~(1 << PD2); // D2 low

// Toggle pin
PORTD ^= (1 << PD2);  // Toggle D2

// Read pin
if (PIND & (1 << PD2)) { /* D2 is high */ }
```

### Timing and Delays

```c
#include <util/delay.h>

_delay_ms(1000);  // Delay 1 second
_delay_us(100);   // Delay 100 microseconds
```

Note: F_CPU must be defined as 16000000UL in CMakeLists.txt for accurate delays.

### Common Peripherals

#### UART Serial
```c
// Initialize UART (9600 baud at 16MHz)
UBRR0H = 0;
UBRR0L = 103;  // 16MHz / (16 * 9600) - 1
UCSR0B = (1 << RXEN0) | (1 << TXEN0);
UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);

// Send byte
while (!(UCSR0A & (1 << UDRE0)));
UDR0 = data;
```

#### Timer/PWM
```c
// Timer0 for PWM on D5/D6
TCCR0A = (1 << WGM01) | (1 << WGM00);  // Fast PWM
TCCR0B = (1 << CS01);  // Prescaler 8
OCR0A = 128;  // 50% duty cycle
```

#### ADC
```c
// Initialize ADC
ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1);
ADMUX = (1 << REFS0);  // AVcc reference

// Read ADC
ADMUX = (ADMUX & 0xF0) | channel;
ADCSRA |= (1 << ADSC);
while (ADCSRA & (1 << ADSC));
uint16_t result = ADC;
```

## Pin Mapping Reference

| Arduino Pin | Port/Pin | Alt Functions |
|------------|----------|---------------|
| D0         | PD0      | RX/PCINT16    |
| D1         | PD1      | TX/PCINT17    |
| D2         | PD2      | INT0/PCINT18  |
| D3         | PD3      | INT1/OC2B/PCINT19 |
| D4         | PD4      | PCINT20/XCK/T0 |
| D5         | PD5      | OC0B/T1/PCINT21 |
| D6         | PD6      | OC0A/AIN0/PCINT22 |
| D7         | PD7      | AIN1/PCINT23  |
| D8         | PB0      | ICP1/CLKO/PCINT0 |
| D9         | PB1      | OC1A/PCINT1   |
| D10        | PB2      | SS/OC1B/PCINT2 |
| D11        | PB3      | MOSI/OC2A/PCINT3 |
| D12        | PB4      | MISO/PCINT4   |
| D13        | PB5      | SCK/PCINT5/LED |
| A0         | PC0      | ADC0/PCINT8   |
| A1         | PC1      | ADC1/PCINT9   |
| A2         | PC2      | ADC2/PCINT10  |
| A3         | PC3      | ADC3/PCINT11  |
| A4         | PC4      | ADC4/SDA/PCINT12 |
| A5         | PC5      | ADC5/SCL/PCINT13 |

## Important Notes

- **Always use absolute pin definitions** (PD2, PB5, etc.) not Arduino pin numbers
- **F_CPU is 16000000UL** - defined in CMakeLists.txt for 16MHz crystal
- **Default programmer**: Arduino as ISP via USB (configured in CMakeLists.txt)
- **Serial port**: Typically `/dev/cu.usbmodem*` on macOS (auto-detected by AVRDUDE)
- **Fuse settings**: Default Arduino Uno fuses (no bootloader required for ISP programming)

## Troubleshooting

### Flash Fails
- Check USB connection
- Verify correct serial port permissions
- Ensure no Serial Monitor is open
- Try unplugging and reconnecting Arduino

### Build Errors
- Ensure AVR-GCC toolchain is installed: `brew install avr-gcc avrdude`
- Check CMakeLists.txt for correct MCU settings (atmega328p)
- Verify all includes are correct for bare metal (no Arduino.h)

### Timing Issues  
- Verify F_CPU matches actual crystal (16000000UL)
- Use `_delay_ms()` and `_delay_us()` from `<util/delay.h>`
- For precise timing, use hardware timers instead of delays

## Example Programs

### Basic Blink
```c
#include <avr/io.h>
#include <util/delay.h>

int main(void) {
    DDRB |= (1 << PB5);  // D13 LED as output
    
    while (1) {
        PORTB ^= (1 << PB5);  // Toggle LED
        _delay_ms(500);
    }
}
```

### Multiple Pin Control
```c
#include <avr/io.h>
#include <util/delay.h>

int main(void) {
    DDRD |= (1 << PD2) | (1 << PD3);  // D2 and D3 as outputs
    
    while (1) {
        PORTD ^= (1 << PD2) | (1 << PD3);  // Toggle both
        _delay_ms(500);
    }
}
```

## Workflow Summary

1. Edit `main.c` with your code
2. Run `make -C build` to compile
3. Run `make -C build flash` to upload to Arduino
4. Monitor serial output if needed via screen or minicom

Remember: This is bare-metal programming - you have direct hardware control but must manage everything manually.