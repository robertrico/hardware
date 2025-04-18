#define LWIP_DNS 1
#define LWIP_SOCKET 1  // Optional, useful if you ever use sockets

#include <stdio.h>
#include "pico/stdlib.h"
#include "pico/cyw43_arch.h"
#include "wifi_manager.hpp"
#include "ota_manager.hpp"
#include "version.h"

#define LED_GRN 14
#define LED_RED 15
#define LED_YLW 16
#define LED_BLU 18
#define LED_WHT 19
#define BTN 20 

volatile bool button_pressed = false;

void gpio_callback(uint gpio, uint32_t events) {
    if (gpio == BTN && (events & GPIO_IRQ_EDGE_FALL)) {
        button_pressed = true;
        gpio_put(LED_BLU, 0);
        gpio_put(LED_WHT, 0);
    }
}

int main() {
    stdio_init_all();

    OTAManager ota;

    char incoming_version[9] = {0};  // 8 + null
    if (ota.checkBootFlag(incoming_version)) {
        printf("Boot flag found for version: %s\n", incoming_version);
        ota.clearBootFlag();   // Clear first, in case B crashes
        ota.jumpToB();    
        // TODO: jump to 0x0C0000
    }

    printf("Initializing Wi-Fi Connection (CPP)...\n");
    if (cyw43_arch_init_with_country(CYW43_COUNTRY_USA)) {
        printf("CYW43 init failed!\n");
        return 1;
    }

    WiFiManager wifi;

    gpio_init(LED_GRN);
    gpio_init(LED_RED);
    gpio_init(LED_YLW);
    gpio_init(LED_BLU);
    gpio_init(LED_WHT);
    gpio_init(BTN);

    gpio_set_dir(LED_GRN, GPIO_OUT);
    gpio_set_dir(LED_RED, GPIO_OUT);
    gpio_set_dir(LED_YLW, GPIO_OUT);
    gpio_set_dir(LED_BLU, GPIO_OUT);
    gpio_set_dir(LED_WHT, GPIO_OUT);

    gpio_set_dir(BTN, GPIO_IN);
    gpio_pull_up(BTN);
    gpio_set_irq_enabled_with_callback(BTN, GPIO_IRQ_EDGE_FALL, true, gpio_callback);
    irq_set_enabled(IO_IRQ_BANK0, true);

    if (wifi.connect()) {
        if (wifi.testConnectivity()) {
            printf("Internet is OK!\n");
            gpio_put(LED_GRN, 1);
        } else {
            printf("No Internet!\n");
            gpio_put(LED_YLW, 1);
        }
    } else {
        printf("Wi-Fi Failed!\n");
        gpio_put(LED_RED, 1);
    }

    if (ota.checkForUpdate()) {
        printf("New version available! Starting download...\n");
        // TODO: parse URL from metadata, for now hardcode:
        if (ota.downloadAndWrite()) {
            printf("Firmware written. Marking for reboot...\n");
            ota.switchToB(VERSION);
        } else {
            printf("Download or write failed\n");
        }
    } else {
        printf("Firmware up-to-date.\n");
    }

    // Your main firmware logic
    while (true) {
        sleep_ms(1000);

        if (button_pressed) {
            button_pressed = false;
            printf("Button interrupt fired!\n");
        
            // LED Dance
            gpio_put(LED_BLU, 0);
            gpio_put(LED_WHT, 0);
            for (int i = 0; i < 5; ++i) {
                gpio_put(LED_BLU, 1);
                sleep_ms(200);
                gpio_put(LED_BLU, 0);
                gpio_put(LED_WHT, 1);
                sleep_ms(200);
                gpio_put(LED_WHT, 0);
                gpio_put(LED_BLU, 1);
                gpio_put(LED_WHT, 1);
                sleep_ms(200);
                gpio_put(LED_BLU, 0);
                gpio_put(LED_WHT, 0);
                sleep_ms(200);
            }
            for (int i = 0; i < 5; ++i) {
                gpio_put(LED_BLU, 0);
                sleep_ms(200);
                gpio_put(LED_BLU, 1);
                gpio_put(LED_WHT, 0);
                sleep_ms(200);
                gpio_put(LED_WHT, 1);
                gpio_put(LED_BLU, 0);
                gpio_put(LED_WHT, 0);
                sleep_ms(200);
                gpio_put(LED_BLU, 1);
                gpio_put(LED_WHT, 1);
                sleep_ms(200);
            }
        } else {
            for (int i = 0; i < 2; ++i) {
                gpio_put(LED_BLU, 1);
                gpio_put(LED_WHT, 0);
                sleep_ms(250);
                gpio_put(LED_BLU, 0);
                sleep_ms(250);
            }
            for (int i = 0; i < 3; ++i) {
                gpio_put(LED_WHT, 1);
                gpio_put(LED_BLU, 0);
                sleep_ms(250);
                gpio_put(LED_WHT, 0);
                sleep_ms(250);
            }
        }
    }

    return 0;
}
