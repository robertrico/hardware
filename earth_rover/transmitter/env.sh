#!/bin/bash

# Project-local aliases/functions

ESP_PORT=/dev/tty.usbmodem1433401

function build() {
    idf.py build
}

function debug() {
    idf.py gdb -p $ESP_PORT
}

function flash() {
  idf.py flash -p $ESP_PORT
}

function monitor() {
   idf.py monitor -p $ESP_PORT
}
