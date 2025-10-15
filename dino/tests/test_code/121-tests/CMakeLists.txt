cmake_minimum_required(VERSION 3.20)

# Project name and language
project(mega2560_tests C ASM)

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

# Function to add a test executable with all necessary targets
function(add_avr_test TEST_NAME SOURCE_FILE)
    set(TARGET_NAME ${TEST_NAME})
    set(ELF_FILE ${TARGET_NAME}.elf)
    set(HEX_FILE ${TARGET_NAME}.hex)
    set(BIN_FILE ${TARGET_NAME}.bin)

    # Create executable
    add_executable(${ELF_FILE} ${SOURCE_FILE})

    # Generate additional output formats
    add_custom_command(
        TARGET ${ELF_FILE}
        POST_BUILD
        COMMAND ${CMAKE_OBJCOPY} -O ihex -R .eeprom ${ELF_FILE} ${HEX_FILE}
        COMMAND ${CMAKE_OBJCOPY} -O binary -R .eeprom ${ELF_FILE} ${BIN_FILE}
        COMMAND ${CMAKE_SIZE} --format=avr --mcu=${MCU} ${ELF_FILE}
        COMMENT "Building ${TEST_NAME}: HEX and BIN files, showing size information"
    )

    # Flash target for this specific test
    add_custom_target(flash_${TEST_NAME}
        COMMAND avrdude -p ${MCU} -c wiring -P ${UPLOAD_PORT} -b 115200 -D -U flash:w:${HEX_FILE}:i
        DEPENDS ${ELF_FILE}
        COMMENT "Flashing ${HEX_FILE} to Arduino Mega 2560"
    )

    # Add to list of hex/bin files to clean
    set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_CLEAN_FILES "${HEX_FILE};${BIN_FILE}")
endfunction()

# ============================================================================
# Test Suite Definitions
# ============================================================================
# Add test executables here using: add_avr_test(test_name source_file.c)

# 74LS121 Monostable Multivibrator Test
add_avr_test(74LS121 74LS121_mega.c)

# Add more tests here as needed:
# add_avr_test(74LS161 74LS161_mega.c)
# add_avr_test(memory_test memory_test.c)

# ============================================================================

# Global flash target (flashes the first/default test)
add_custom_target(flash
    COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target flash_74LS121
    COMMENT "Flashing default test (74LS121)"
)

# Fuses target (optional - use with caution)
add_custom_target(set_fuses
    COMMAND avrdude -p ${MCU} -c wiring -P ${UPLOAD_PORT} -b 115200 -U lfuse:w:0xFF:m -U hfuse:w:0xD8:m -U efuse:w:0xFD:m
    COMMENT "Setting fuses for Arduino Mega 2560 (CAUTION: This can brick your board if wrong!)"
)
