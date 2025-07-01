#ifndef INCLUDE_H
#define INCLUDE_H

/**
 * @file include.h
 * @brief Main include file for ESP-IDF based receiver project.
 *
 * This header file includes essential ESP-IDF libraries required for:
 * - GPIO control (`driver/gpio.h`)
 * - Wi-Fi functionality (`esp_wifi.h`)
 * - ESP-NOW communication protocol (`esp_now.h`)
 * - Event loop handling (`esp_event.h`)
 * - Logging utilities (`esp_log.h`)
 *
 * Ensure this file is included in source files that require access to these ESP-IDF features.
 */

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "driver/gpio.h"
#include "driver/spi_master.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_now.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "freertos/queue.h"
#include "nvs_flash.h"

#define ESPNOW_CHANNEL 1
#define LED_GPIO GPIO_NUM_20  // D7

#define GPIO_HANDSHAKE  GPIO_NUM_2
#define GPIO_MOSI       GPIO_NUM_10
#define GPIO_MISO       GPIO_NUM_9
#define GPIO_SCLK       GPIO_NUM_8
#define GPIO_CS         GPIO_NUM_5

#define SENDER_HOST SPI2_HOST

// Receiver Ready to Receive
extern QueueHandle_t rdySem;
extern spi_device_handle_t spiDeviceHandle;

void vSendSPI(uint8_t* payload);

#endif // INCLUDE_H