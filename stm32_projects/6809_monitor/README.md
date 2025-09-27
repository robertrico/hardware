OpenOCD
openocd -f interface/stlink.cfg -f target/stm32l4x.cfg

GDB
arm-none-eabi-gdb -ex "target extended-remote localhost:3333" 6809_monitor.elf