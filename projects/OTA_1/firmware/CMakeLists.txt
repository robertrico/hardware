set(PROJECT_NAME firmware)

cmake_minimum_required(VERSION 3.13)

set(PICO_SDK_PATH "../../../pico-sdk")
set(PICO_BOARD pico_w)

# Import Pico SDK
include("../pico_sdk_import.cmake")

project(firmware C CXX ASM)

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
add_executable(firmware
    main.cpp
)

pico_set_linker_script(firmware ${CMAKE_CURRENT_SOURCE_DIR}/linker.ld)

target_include_directories(firmware PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# Link with standard libraries
target_link_libraries(firmware
    pico_stdlib
)

pico_add_extra_outputs(${PROJECT_NAME})