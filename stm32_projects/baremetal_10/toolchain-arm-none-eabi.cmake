set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)

# Prevent running executable linking tests
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(CMAKE_C_COMPILER "/Applications/ARM/bin/arm-none-eabi-gcc")
set(CMAKE_CXX_COMPILER "/Applications/ARM/bin/arm-none-eabi-g++")
set(CMAKE_ASM_COMPILER "/Applications/ARM/bin/arm-none-eabi-gcc")

# Avoid default linker flags
set(CMAKE_EXE_LINKER_FLAGS "" CACHE INTERNAL "")
