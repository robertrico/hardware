add_library(ssd1306 ssd1306.c)

target_include_directories(ssd1306 PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(ssd1306
    pico_stdlib
    hardware_i2c
)
