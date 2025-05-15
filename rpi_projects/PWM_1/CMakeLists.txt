cmake_minimum_required(VERSION 3.13)
set(PROJECT_NAME "PWM_1")

# Import Pico SDK
set(PICO_SDK_PATH "../../pico-sdk")
set(PICO_BOARD pico_w)
include(pico_sdk_import.cmake)

project(${PROJECT_NAME} C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(PICO_CYW43_SUPPORTED 1)

# Required for USB wait (optional)
if (NOT DEFINED PICO_STDIO_USB_CONNECT_WAIT_TIMEOUT_MS)
    set(PICO_STDIO_USB_CONNECT_WAIT_TIMEOUT_MS 3000)
endif()

# Initialize the SDK
pico_sdk_init()

# Add your project executable
add_executable(${PROJECT_NAME}
    main.c
)

target_include_directories(${PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}) 

# Link with standard libraries
target_link_libraries(${PROJECT_NAME}
    pico_stdlib
    hardware_pwm
)

# Add USB/UART/Flash output formats
pico_add_extra_outputs(${PROJECT_NAME})
