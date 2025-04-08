#define LWIP_DNS 1
#define LWIP_SOCKET 1  // Optional, useful if you ever use sockets

#include <stdio.h>
#include "pico/stdlib.h"
#include "pico/cyw43_arch.h"
#include "wifi_manager.hpp"

int main() {
    stdio_init_all();

    printf("Initializing Wi-Fi Connection (CPP)...\n");
    if (cyw43_arch_init_with_country(CYW43_COUNTRY_USA)) {
        printf("CYW43 init failed!\n");
        return 1;
    }

    WiFiManager wifi;

    if (wifi.connect()) {
        if (wifi.testConnectivity()) {
            printf("Internet is OK!\n");
        } else {
            printf("No Internet!\n");
        }
    } else {
        printf("Wi-Fi Failed!\n");
    }

    return 0;
}
