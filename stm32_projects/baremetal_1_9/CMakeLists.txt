cmake_minimum_required(VERSION 3.15)
project(arm_test LANGUAGES C)

file(GLOB SOURCES "${CMAKE_SOURCE_DIR}/*.c")

add_executable(arm_test.elf
    ${SOURCES}
)

target_include_directories(arm_test.elf PRIVATE
    ${CMAKE_SOURCE_DIR}/Include
    ${CMAKE_SOURCE_DIR}/Include/CMSIS/Include
    ${CMAKE_SOURCE_DIR}/Include/CMSIS/Device/ST/STM32F4xx/Include
)

target_compile_options(arm_test.elf PRIVATE
    -mcpu=cortex-m4
    -mthumb
    -std=gnu11
    -g
)

target_link_options(arm_test.elf PRIVATE
    -mcpu=cortex-m4
    -mthumb
    -std=gnu11
    -T${CMAKE_SOURCE_DIR}/stm32f411re.ld
    -nostdlib
    -g
    -Wl,--print-memory-usage
)

set_target_properties(arm_test.elf PROPERTIES LINK_FLAGS "-Wl,-Map=${CMAKE_SOURCE_DIR}/build/arm_test.map")
