cmake_minimum_required(VERSION 3.13)

set(PICO_SDK_PATH "../../pico-sdk")
set(PICO_BOARD pico_w)
# Import Pico SDK
include(pico_sdk_import.cmake)

project(WiFi_Test_1 C CXX ASM)

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
add_executable(WiFi_Test_1
    main.c
)
target_include_directories(WiFi_Test_1 PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})  # ✅ add this

# Link with standard libraries
target_link_libraries(WiFi_Test_1 pico_stdlib hardware_i2c)

add_subdirectory(../pico-libs/pico-ssd1306 pico-ssd1306)

target_link_libraries(WiFi_Test_1
    pico_stdlib
    hardware_i2c
    ssd1306
    pico_cyw43_arch_lwip_threadsafe_background
)

# Add USB/UART/Flash output formats
pico_add_extra_outputs(WiFi_Test_1)
