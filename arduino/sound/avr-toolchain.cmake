# AVR Toolchain File for CMake

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR avr)

# AVR toolchain programs
find_program(CMAKE_C_COMPILER avr-gcc REQUIRED)
find_program(CMAKE_CXX_COMPILER avr-g++ REQUIRED)
find_program(CMAKE_ASM_COMPILER avr-gcc REQUIRED)
find_program(CMAKE_AR avr-ar REQUIRED)
find_program(CMAKE_RANLIB avr-ranlib REQUIRED)
find_program(CMAKE_OBJCOPY avr-objcopy REQUIRED)
find_program(CMAKE_OBJDUMP avr-objdump REQUIRED)
find_program(CMAKE_SIZE avr-size REQUIRED)
find_program(AVRDUDE avrdude REQUIRED)

# Prevent CMake from testing the compiler (requires execution which won't work for cross-compilation)
set(CMAKE_C_COMPILER_WORKS 1)
set(CMAKE_CXX_COMPILER_WORKS 1)

# Set find root path mode
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
