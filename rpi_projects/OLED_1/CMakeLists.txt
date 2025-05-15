cmake_minimum_required(VERSION 3.13)

set(PICO_SDK_PATH "../../pico-sdk")
# Import Pico SDK
include(pico_sdk_import.cmake)

project(OLED_1 C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Required for USB wait (optional)
if (NOT DEFINED PICO_STDIO_USB_CONNECT_WAIT_TIMEOUT_MS)
    set(PICO_STDIO_USB_CONNECT_WAIT_TIMEOUT_MS 3000)
endif()

# Initialize the SDK
pico_sdk_init()

# Add your project executable
add_executable(OLED_1
    oled.c
)

# Link with standard libraries
target_link_libraries(OLED_1 pico_stdlib hardware_i2c)

add_subdirectory(../pico-libs/pico-ssd1306 pico-ssd1306)

target_link_libraries(OLED_1
    pico_stdlib
    hardware_i2c
    ssd1306
)


# Add USB/UART/Flash output formats
pico_add_extra_outputs(OLED_1)
