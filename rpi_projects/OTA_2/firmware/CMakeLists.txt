add_executable(firmware)

target_sources(firmware PRIVATE firmware.cpp)

pico_set_linker_script(firmware ${CMAKE_HOME_DIRECTORY}/linkers/firmware_memmap.ld)

# Pull in our pico_stdlib which pulls in commonly used features
target_link_libraries(firmware PUBLIC
                      hardware_watchdog
                      pico_standard_link
                      pico_stdlib
                      hardware_flash)
                      
# create map/bin/hex file etc.
pico_add_extra_outputs(firmware)