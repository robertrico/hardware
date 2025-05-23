#ifndef INTERRUPTS_H
#define INTERRUPTS_H

/**
 * @file interrupts.h
 * @brief Declarations for ESP-NOW receive callback and related includes.
 */

#include "driver/gpio.h"
#include "esp_wifi.h"
#include "esp_now.h"
#include "esp_log.h"

/**
 * @brief Callback function for receiving ESP-NOW data.
 *
 * @param info Pointer to information about the received packet.
 * @param data Pointer to the received data buffer.
 * @param len Length of the received data.
 */
void vButtonReceive(const esp_now_recv_info_t* info, const uint8_t* data, int len);

#endif // INTERRUPTS_H