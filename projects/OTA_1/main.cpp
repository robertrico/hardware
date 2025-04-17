#define LWIP_DNS 1
#define LWIP_SOCKET 1  // Optional, useful if you ever use sockets

#include <stdio.h>
#include "pico/stdlib.h"
#include "pico/cyw43_arch.h"
#include "wifi_manager.hpp"

#define LED_GRN 14
#define LED_RED 15
#define LED_YLW 16

int main() {
    stdio_init_all();
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

    return 0;
}
