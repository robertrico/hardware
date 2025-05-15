# Bare-Metal Blink on Arduino Uno

This is a minimal bare-metal C project for the Arduino Uno (ATmega328P) that toggles **digital pin 2 (PD2)** to blink an external LED. No Arduino libraries or core are used — just direct register access and the `avr-gcc` toolchain.

---

## 🧠 Objective

Learn the fundamentals of AVR bare-metal programming by:

* Manually setting up GPIO using AVR registers
* Using `avr-gcc` and `CMake` for compilation
* Uploading using `avrdude` via the bootloader

---

## 💡 What It Does

Toggles pin **D2 (PD2)** every 1.75 seconds using `_delay_ms()` from `util/delay.h`. A connected LED will blink visibly.

---

## 📟 Hardware

* Arduino Uno (ATmega328P)
* External LED + 330Ω resistor
* LED anode to **D2**, cathode to **GND** through resistor

---

## 💻 Code (main.c)

```c
#include <avr/io.h>
#include <util/delay.h>

int main(void)
{
    DDRD |= (1 << PD2); // Set PD2 (digital pin 2) as output

    while (1) 
    {
        PORTD ^= (1 << PD2); // Toggle PD2
        _delay_ms(1750);     // Delay 1.75 seconds
    }
}
```

---

## 🧰 Build and Upload (Manual GCC)

### Step 1: Compile

```bash
avr-gcc -mmcu=atmega328p -DF_CPU=16000000UL -Os -o blink.elf main.c
```

### Step 2: Convert to HEX

```bash
avr-objcopy -O ihex -R .eeprom blink.elf blink.hex
```

### Step 3: Flash to Arduino

```bash
avrdude -c arduino -p m328p -P /dev/tty.usbmodem1443401 -b 115200 -U flash:w:blink.hex
```

---

## ⚙️ CMake-Based Workflow

### Project Structure

```
project/
├── CMakeLists.txt
├── toolchain-avr.cmake
├── main.c
```

### `CMakeLists.txt`

```cmake
cmake_minimum_required(VERSION 3.12)
project(blink C)

set(MCU atmega328p)
set(F_CPU 16000000UL)
set(BAUD 115200)
set(PORT /dev/tty.usbmodem1443401)

set(CMAKE_C_FLAGS "-mmcu=${MCU} -DF_CPU=${F_CPU} -Os")

add_executable(blink.elf main.c)

add_custom_command(TARGET blink.elf POST_BUILD
    COMMAND avr-objcopy -O ihex -R .eeprom blink.elf blink.hex
    COMMENT "Generating HEX file"
)

add_custom_target(flash
    COMMAND avrdude -c arduino -p ${MCU} -P ${PORT} -b ${BAUD} -U flash:w:blink.hex
    DEPENDS blink.elf
    COMMENT "Flashing to Arduino Uno"
)
```

### `toolchain-avr.cmake`

```cmake
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR avr)

set(CMAKE_C_COMPILER avr-gcc)
set(CMAKE_CXX_COMPILER avr-g++)
set(CMAKE_AR avr-ar)
set(CMAKE_OBJCOPY avr-objcopy)
set(CMAKE_SIZE avr-size)

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
```

### Build and Flash with CMake

```bash
mkdir build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE=../toolchain-avr.cmake ..
make
make flash
```

---

## ✅ Expected Behavior

An external LED connected to pin D2 will blink **on/off** every 1.75 seconds.

---

## 🔧 Notes

* You must use `PORTD` and `DDRD` for pin D2 (PD2), **not PORTB**.
* `_delay_ms()` needs `-DF_CPU=16000000UL` if timing is critical.
* If unsure which port corresponds to which Arduino pin, refer to the AVR-to-Arduino pin mapping table.

---

## 📦 Next Steps

* Blink on different pins (D13, D10)
* Add button input (e.g., D3/INT1)
* Investigate fuse settings and watchdog behavior

---

## 🧭 Learn More

* [AVR libc Documentation](https://github.com/avrdudes/avr-libc/)
* [ATmega328P Datasheet](https://www.microchip.com/en-us/search?searchQuery=ATMEGA328P&category=ALL&fq=start%3D0%26rows%3D10)
* [Uno Pin Mapping](https://www.arnabkumardas.com/arduino-tutorial/pin-configuration-and-io-multiplexing/)
https://datasheet.octopart.com/A000066-Arduino-datasheet-38879526.pdf