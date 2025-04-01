cmake_minimum_required(VERSION 3.13)

set(PICO_SDK_PATH "../../pico-sdk")
set(PICO_BOARD pico_w)
# Import Pico SDK
include(pico_sdk_import.cmake)

project(Wifi_Test_4 C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(PICO_CYW43_SUPPORTED 1)

# Required for USB wait (optional)
if (NOT DEFINED PICO_STDIO_USB_CONNECT_WAIT_TIMEOUT_MS)
    set(PICO_STDIO_USB_CONNECT_WAIT_TIMEOUT_MS 3000)
endif()

# WiFi credentials
if(DEFINED ENV{WIFI_SSID})
    add_compile_definitions(WIFI_SSID="$ENV{WIFI_SSID}")
endif()
if(DEFINED ENV{WIFI_PASSWORD})
    add_compile_definitions(WIFI_PASSWORD="$ENV{WIFI_PASSWORD}")
endif()

# Initialize the SDK
pico_sdk_init()

# Add your project executable
add_executable(Wifi_Test_4
    main.c
)
target_include_directories(Wifi_Test_4 PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})  # ✅ add this

# Link with standard libraries
target_link_libraries(Wifi_Test_4 pico_stdlib hardware_i2c)

target_link_libraries(Wifi_Test_4
    pico_stdlib
    hardware_i2c
    pico_cyw43_arch_lwip_threadsafe_background
)

# Add USB/UART/Flash output formats
pico_add_extra_outputs(Wifi_Test_4)
