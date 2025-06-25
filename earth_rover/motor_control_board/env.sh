#!/bin/bash

# Project-local aliases/functions

function build() {
  cmake -S . -B build && cmake --build build
}

function debug() {
  arm-none-eabi-gdb build/motor_control_board.elf
}

function monitor() {
   openocd -f interface/stlink.cfg -f target/stm32l4x.cfg
}
