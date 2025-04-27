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
    lib/ota_manager.cpp
    lib/flash_manager.cpp
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

function (target_compile_link_options Name Option)
    target_compile_options(${Name} PRIVATE ${Option})
    target_link_options(${Name} PRIVATE ${Option})
endfunction ()
# Optimize for size

target_compile_link_options(firmware "-Os")
target_compile_link_options(firmware "-ffunction-sections")
target_compile_link_options(firmware "-fdata-sections")


# create map/bin/hex file etc.
pico_add_extra_outputs(bootloader)