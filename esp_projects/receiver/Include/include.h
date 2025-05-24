#define LED_GPIO GPIO_NUM_20  // D7
#define ESPNOW_CHANNEL 1

#include "driver/gpio.h"
#include "esp_wifi.h"
#include "esp_now.h"
#include "esp_event.h"
#include "esp_log.h"
#include "nvs_flash.h"