cmake_minimum_required(VERSION 3.12)
project(arduino_tests C)

set(MCU atmega328p)
set(F_CPU 16000000UL)
set(BAUD 115200)
set(PORT /dev/tty.usbserial-143120 )

# Clock frequency parameter (default 1MHz if not specified)
set(CLOCK_FREQ "1000000" CACHE STRING "Clock generator frequency in Hz")

# Base compiler flags
set(CMAKE_C_FLAGS "-mmcu=${MCU} -DF_CPU=${F_CPU} -DCLOCK_FREQ=${CLOCK_FREQ} -Os")

# Test selection (default to no test)
set(TEST_TYPE "" CACHE STRING "Test type to build (373, 245, etc.)")

# Include directories
include_directories(headers)

# Source files (always include common test utilities)
set(SOURCES src/main.c src/test_common.c)

# Add test-specific sources and definitions
if(TEST_TYPE STREQUAL "373")
    add_definitions(-DTEST_373)
    list(APPEND SOURCES src/test_373.c)
    message(STATUS "Building 74LS373 test")
elseif(TEST_TYPE STREQUAL "245_373")
    add_definitions(-DTEST_245_373)
    list(APPEND SOURCES src/test_245_373.c)
    message(STATUS "Building 74LS245+373 combined test")
elseif(TEST_TYPE STREQUAL "ir")
    add_definitions(-DTEST_IR)
    list(APPEND SOURCES src/test_ir.c)
    message(STATUS "Building Instruction Register (244+373) test")
elseif(TEST_TYPE STREQUAL "register")
    add_definitions(-DTEST_REGISTER)
    list(APPEND SOURCES src/test_register.c)
    message(STATUS "Building Register module (245+373+121) test")
elseif(TEST_TYPE STREQUAL "pulse")
    add_definitions(-DTEST_PULSE)
    list(APPEND SOURCES src/test_pulse.c)
    # Check for register selection
    if(PULSE_REG STREQUAL "b")
        add_definitions(-DPULSE_TEST_REG_B)
        message(STATUS "Building 74LS121 pulse test for Register B")
    else()
        message(STATUS "Building 74LS121 pulse test for Register A")
    endif()
elseif(TEST_TYPE STREQUAL "245")
    add_definitions(-DTEST_245)
    # list(APPEND SOURCES src/test_245.c)
    message(STATUS "Building 74LS245 test")
elseif(TEST_TYPE STREQUAL "clock")
    add_definitions(-DTEST_CLOCK -DSTANDALONE_CLOCK)
    set(SOURCES src/clock.c)
    message(STATUS "Building clock generator at ${CLOCK_FREQ}Hz")
else()
    message(STATUS "Building default blink test (no test selected)")
endif()

# Create executable
add_executable(test.elf ${SOURCES})

# Generate HEX file
add_custom_command(TARGET test.elf POST_BUILD
    COMMAND avr-objcopy -O ihex -R .eeprom test.elf test.hex
    COMMENT "Generating HEX file"
)

# Flash target
add_custom_target(flash
    COMMAND avrdude -c arduino -p ${MCU} -P ${PORT} -b ${BAUD} -U flash:w:test.hex
    DEPENDS test.elf
    COMMENT "Flashing to Arduino Uno"
)

# Clean target
add_custom_target(clean-all
    COMMAND ${CMAKE_COMMAND} -E remove test.elf test.hex
    COMMENT "Cleaning build files"
)