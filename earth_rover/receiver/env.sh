#!/bin/bash

# Project-local aliases/functions

ESP_PORT=/dev/tty.usbmodem1441101

function build() {
    idf.py build
}

function debug() {
    idf.py gdb
}

function flash() {
  idf.py flash -p $ESP_PORT
}

function monitor() {
   idf.py monitor -p $ESP_PORT
}
