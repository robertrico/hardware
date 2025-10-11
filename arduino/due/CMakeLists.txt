cmake_minimum_required(VERSION 3.20)

# Set toolchain before project()
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)

# Toolchain settings
set(CMAKE_C_COMPILER arm-none-eabi-gcc)
set(CMAKE_CXX_COMPILER arm-none-eabi-g++)
set(CMAKE_ASM_COMPILER arm-none-eabi-gcc)
set(CMAKE_OBJCOPY arm-none-eabi-objcopy)
set(CMAKE_SIZE arm-none-eabi-size)

# Don't try to execute cross-compiled programs on host
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# Project
project(arduino_due_blink C ASM)

# MCU settings
set(MCU_ARCH cortex-m3)
set(MCU_CHIP SAM3X8E)
set(F_CPU 84000000L)

# Compiler flags
set(CPU_FLAGS "-mcpu=${MCU_ARCH} -mthumb -mfloat-abi=soft")
set(COMMON_FLAGS "${CPU_FLAGS} -Wall -ffunction-sections -fdata-sections")

set(CMAKE_C_FLAGS "${COMMON_FLAGS} -std=gnu11")
set(CMAKE_C_FLAGS_DEBUG "-O0 -g3")
set(CMAKE_C_FLAGS_RELEASE "-O2")

# Linker flags
set(LINKER_SCRIPT ${CMAKE_SOURCE_DIR}/linker/link_due.ld)
set(CMAKE_EXE_LINKER_FLAGS "${CPU_FLAGS} -T${LINKER_SCRIPT} -Wl,--gc-sections -Wl,-Map=${PROJECT_NAME}.map --specs=nosys.specs -nostartfiles")

# Include directories
include_directories(
    ${CMAKE_SOURCE_DIR}/include
)

# Source files
set(SOURCES
    src/startup_due.c
    src/blink_due.c
)

# Create executable
add_executable(${PROJECT_NAME}.elf ${SOURCES})

# Add defines
target_compile_definitions(${PROJECT_NAME}.elf PRIVATE
    -D__${MCU_CHIP}__
    -DF_CPU=${F_CPU}
)

# Post-build commands to create .bin and .hex
add_custom_command(TARGET ${PROJECT_NAME}.elf POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O binary ${PROJECT_NAME}.elf ${PROJECT_NAME}.bin
    COMMAND ${CMAKE_OBJCOPY} -O ihex ${PROJECT_NAME}.elf ${PROJECT_NAME}.hex
    COMMAND ${CMAKE_SIZE} ${PROJECT_NAME}.elf
    COMMENT "Creating binary and hex files, showing size"
)

# Custom flash target
add_custom_target(flash
    COMMAND ${CMAKE_SOURCE_DIR}/flash.sh
    DEPENDS ${PROJECT_NAME}.elf
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Flashing to Arduino Due..."
)

# Custom clean target
add_custom_target(clean-all
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}
    COMMENT "Removing build directory"
)
