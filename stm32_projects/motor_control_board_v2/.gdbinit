# .gdbinit

set confirm off
symbol-file build/motor_control_board.elf
target extended-remote :3333
