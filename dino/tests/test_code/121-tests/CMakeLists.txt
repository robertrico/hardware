cmake_minimum_required(VERSION 3.20)

# Project name and language
project(mega2560_blink C ASM)

# Set the MCU and frequency
set(MCU atmega2560)
set(F_CPU 16000000UL)
set(BAUD 115200)

# Upload port configuration (can be overridden with -DUPLOAD_PORT=...)
if(NOT DEFINED UPLOAD_PORT)
    set(UPLOAD_PORT "/dev/tty.usbserial-143440" CACHE STRING "Arduino upload port")
endif()

# Compiler flags
set(CMAKE_C_FLAGS "-mmcu=${MCU} -DF_CPU=${F_CPU} -DBAUD=${BAUD} -Os -Wall -Wextra -std=gnu99")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ffunction-sections -fdata-sections")

# Linker flags
set(CMAKE_EXE_LINKER_FLAGS "-mmcu=${MCU} -Wl,--gc-sections")

# Executable name
set(EXECUTABLE ${PROJECT_NAME}.elf)

# Source files
set(SOURCES
    blink_mega.c
)

# Create executable
add_executable(${EXECUTABLE} ${SOURCES})

# Generate additional output formats
add_custom_command(
    TARGET ${EXECUTABLE}
    POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O ihex -R .eeprom ${EXECUTABLE} ${PROJECT_NAME}.hex
    COMMAND ${CMAKE_OBJCOPY} -O binary -R .eeprom ${EXECUTABLE} ${PROJECT_NAME}.bin
    COMMAND ${CMAKE_SIZE} --format=avr --mcu=${MCU} ${EXECUTABLE}
    COMMENT "Building HEX and BIN files, and showing size information"
)

# Flash target
add_custom_target(flash
    COMMAND avrdude -p ${MCU} -c wiring -P ${UPLOAD_PORT} -b 115200 -D -U flash:w:${PROJECT_NAME}.hex:i
    DEPENDS ${EXECUTABLE}
    COMMENT "Flashing ${PROJECT_NAME}.hex to Arduino Mega 2560"
)

# Fuses target (optional - use with caution)
add_custom_target(set_fuses
    COMMAND avrdude -p ${MCU} -c wiring -P ${UPLOAD_PORT} -b 115200 -U lfuse:w:0xFF:m -U hfuse:w:0xD8:m -U efuse:w:0xFD:m
    COMMENT "Setting fuses for Arduino Mega 2560 (CAUTION: This can brick your board if wrong!)"
)

# Clean hex and bin files
set_directory_properties(
    PROPERTIES ADDITIONAL_CLEAN_FILES "${PROJECT_NAME}.hex;${PROJECT_NAME}.bin"
)
