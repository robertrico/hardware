/*
 * Copyright (c) 2024 Jakub Zimnol
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

 #ifndef BOOTLOADER_H
 #define BOOTLOADER_H
#include "hardware/gpio.h"
#include <cstdio>
#include <pico/stdlib.h>
#include "lib/wifi_manager.hpp"
#include "lib/ota_manager.hpp"

#define FLASH_OFFSET(addr) ((addr) - XIP_BASE) 
#define FLASH_APP_START (XIP_BASE + (508 * 1024)) // 508kB Bootloader Size
#define BOOT_CONFIG_START (XIP_BASE + (2048 * 1024) - 4096) // 2048kB Bootloader Size
#define BOOTCONFIG_MAGIC 0x424F4F54

#define LED_GRN 14
#define LED_RED 15
#define LED_YLW 16
#define LED_PIN 19 
#define LED_PIN2 18 

 #ifdef __cplusplus
 extern "C" {
 #endif

 struct BootConfig {
    uint32_t const magic = BOOTCONFIG_MAGIC;
    uint32_t const flash_app_start = FLASH_APP_START;
    char mode[5];
    char version[9];
    char padding[4074];
};

extern const BootConfig boot_config_flash;
 
 #ifdef __cplusplus
 }
 #endif
 
 #endif // BOOTLOADER_H
 