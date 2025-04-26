cmake_minimum_required(VERSION 3.13)
# Comment the line below in for the Pico W examples to build
set(PICO_BOARD pico_w)

# Pull in SDK (must be before project)
include(pico_sdk_import.cmake)

project(bootloader C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(PICO_CYW43_SUPPORTED 1)

# WiFi credentials
if(DEFINED ENV{WIFI_SSID})
    add_compile_definitions(WIFI_SSID="$ENV{WIFI_SSID}")
endif()
if(DEFINED ENV{WIFI_PASSWORD})
    add_compile_definitions(WIFI_PASSWORD="$ENV{WIFI_PASSWORD}")
endif()

pico_sdk_init()

add_executable(bootloader
    bootloader.cpp
    lib/wifi_manager.cpp
    )

target_link_libraries(bootloader PUBLIC
                      hardware_watchdog
                      pico_stdlib
                      pico_stdio_usb
                      hardware_flash
                      hardware_structs
                      hardware_resets
                      cmsis_core
                      pico_cyw43_arch_lwip_threadsafe_background
                      )

target_sources(bootloader PRIVATE bootloader.cpp)

pico_set_linker_script(bootloader ${CMAKE_HOME_DIRECTORY}/linkers/bootloader_memmap.ld)

target_include_directories(${PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

add_subdirectory(firmware)

# create map/bin/hex file etc.
pico_add_extra_outputs(bootloader)