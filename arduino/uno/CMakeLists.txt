cmake_minimum_required(VERSION 3.20)

# Set toolchain file before project()
set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/avr-toolchain.cmake)

# Project definition
project(avr_uno_blink C)

# MCU settings for Arduino Uno
set(MCU atmega328p)
set(F_CPU 16000000UL)
set(BAUD 115200)

# Programmer settings
set(PROGRAMMER arduino)
set(PORT /dev/tty.usbmodem13401)
set(AVRDUDE_BAUD 115200)

# Compiler flags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mmcu=${MCU}")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DF_CPU=${F_CPU}")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DBAUD=${BAUD}")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Os")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=gnu99")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -funsigned-char -funsigned-bitfields")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fpack-struct -fshort-enums")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ffunction-sections -fdata-sections")

# Linker flags
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -mmcu=${MCU}")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--gc-sections")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-Map=${PROJECT_NAME}.map")

# Executable target
add_executable(${PROJECT_NAME}.elf blink_test.c)

# Generate HEX file
add_custom_command(
    TARGET ${PROJECT_NAME}.elf POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O ihex -R .eeprom $<TARGET_FILE:${PROJECT_NAME}.elf> ${PROJECT_NAME}.hex
    COMMENT "Creating HEX file: ${PROJECT_NAME}.hex"
)

# Generate disassembly listing
add_custom_command(
    TARGET ${PROJECT_NAME}.elf POST_BUILD
    COMMAND ${CMAKE_OBJDUMP} -h -S $<TARGET_FILE:${PROJECT_NAME}.elf> > ${PROJECT_NAME}.lss
    COMMENT "Creating disassembly listing: ${PROJECT_NAME}.lss"
)

# Show size information
add_custom_command(
    TARGET ${PROJECT_NAME}.elf POST_BUILD
    COMMAND ${CMAKE_SIZE} -C --mcu=${MCU} $<TARGET_FILE:${PROJECT_NAME}.elf>
    COMMENT "Size information:"
)

# Flash target
add_custom_target(flash
    COMMAND ${AVRDUDE} -p ${MCU} -c ${PROGRAMMER} -P ${PORT} -b ${AVRDUDE_BAUD} -D -V -U flash:w:${PROJECT_NAME}.hex:i
    DEPENDS ${PROJECT_NAME}.elf
    COMMENT "Flashing ${PROJECT_NAME}.hex to ${PORT}"
)

# Clean target for HEX and LSS files
set_directory_properties(PROPERTIES ADDITIONAL_CLEAN_FILES "${PROJECT_NAME}.hex;${PROJECT_NAME}.lss;${PROJECT_NAME}.map")
