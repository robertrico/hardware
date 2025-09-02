cmake_minimum_required(VERSION 3.13)

set(PICO_SDK_PATH "../../../../pico-sdk")
set(PICO_TOOLCHAIN_PATH "/Applications/ARM/bin")
# Import Pico SDK
include(pico_sdk_import.cmake)

project(pico_bare C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Required for USB wait (optional)
if (NOT DEFINED PICO_STDIO_USB_CONNECT_WAIT_TIMEOUT_MS)
    set(PICO_STDIO_USB_CONNECT_WAIT_TIMEOUT_MS 3000)
endif()

# Initialize the SDK
pico_sdk_init()

# Add your project executable
add_executable(pico_bare main.c)

# Link with standard libraries
target_link_libraries(pico_bare pico_stdlib)

# Add USB/UART/Flash output formats
# pico_add_extra_outputs(pico_bare)
