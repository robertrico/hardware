cmake_minimum_required(VERSION 3.13)

set(PICO_SDK_PATH "../../../../pico-sdk-master")
set(PICO_TOOLCHAIN_PATH "/Applications/ARM/bin")

# Set board type to Pico W
set(PICO_BOARD pico_w)

# Import Pico SDK
include(pico_sdk_import.cmake)

project(pico_bare C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Debug build type for GDB
set(CMAKE_BUILD_TYPE Debug)

# Disable USB stdio wait to prevent hanging
set(PICO_STDIO_USB_CONNECT_WAIT_TIMEOUT_MS 0)

# Initialize the SDK
pico_sdk_init()

# Add your project executable
add_executable(pico_bare main.c)

# Link with standard libraries
target_link_libraries(pico_bare 
    pico_stdlib
)

# Enable debug output generation (required for OpenOCD/GDB)
pico_add_extra_outputs(pico_bare)

# Enable stdio output (optional, useful for debugging)
pico_enable_stdio_usb(pico_bare 1)
pico_enable_stdio_uart(pico_bare 0)
