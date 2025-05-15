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