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

int main() {
    stdio_init_all();

    OTAManager ota;

    char incoming_version[9] = {0};  // 8 + null
    if (ota.checkBootFlag(incoming_version)) {
        printf("Boot flag found for version: %s\n", incoming_version);

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

    gpio_set_dir(LED_GRN, GPIO_OUT);
    gpio_set_dir(LED_RED, GPIO_OUT);
    gpio_set_dir(LED_YLW, GPIO_OUT);

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

    while (true) {
        // Your main firmware logic
        // For now, just blink an LED or print heartbeat
        sleep_ms(1000);
        printf(".\n");
    }

    return 0;
}
