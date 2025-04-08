#include "wifi_manager.hpp"
#include "pico/stdlib.h"
#include "lwip/dns.h"
#include "lwip/dhcp.h"
#include "lwip/netif.h"
#include <cstdio>

#define WIFI_CONNECT_RETRIES 5
#define WIFI_RETRY_DELAY_MS 3000

static bool resolved = false;

static void dns_callback(const char *name, const ip_addr_t *ipaddr, void *arg) {
    if (ipaddr) {
        printf("✅ DNS callback: %s resolved to %s\n", name, ipaddr_ntoa(ipaddr));
        *(bool *)arg = true;
    } else {
        printf("❌ DNS callback: failed to resolve %s\n", name);
        *(bool *)arg = false;
    }
}

WiFiManager::WiFiManager() {
    setupGpios();
    dns_init();
}

void WiFiManager::setupGpios() {
    i2c_init(i2c1, 400000);
    gpio_set_function(2, GPIO_FUNC_I2C);
    gpio_set_function(3, GPIO_FUNC_I2C);
    gpio_pull_up(2);
    gpio_pull_up(3);
}

bool WiFiManager::connect() {
    cyw43_arch_enable_sta_mode();
    auto netif = netif_default;

    for (int attempt = 1; attempt <= WIFI_CONNECT_RETRIES; ++attempt) {
        printf("🌐 Attempt %d to connect...\n", attempt);
        int result = cyw43_arch_wifi_connect_timeout_ms(
            WIFI_SSID, WIFI_PASSWORD, CYW43_AUTH_WPA2_AES_PSK, 20000);

        if (result == 0) {
            printf("✅ Connected. Starting DHCP...\n");
            netif_set_up(netif);
            dhcp_start(netif);

            uint32_t start = to_ms_since_boot(get_absolute_time());
            while (!dhcp_supplied_address(netif)) {
                if (to_ms_since_boot(get_absolute_time()) - start > 10000) {
                    printf("❌ DHCP timeout.\n");
                    return false;
                }
                sleep_ms(500);
            }

            printf("✅ Got IP: %s\n", ipaddr_ntoa(&netif->ip_addr));
            return true;
        }

        printf("❌ Failed to connect. Retrying...\n");
        sleep_ms(WIFI_RETRY_DELAY_MS);
    }

    return false;
}

bool WiFiManager::testConnectivity() {
    ip_addr_t addr;
    resolved = false;
    err_t err = dns_gethostbyname("google.com", &addr, dns_callback, &resolved);

    if (err == ERR_OK) return true;
    if (err == ERR_INPROGRESS) {
        for (int i = 0; i < 100 && !resolved; i++) {
            cyw43_arch_poll();
            sleep_ms(50);
        }
        return resolved;
    }

    return false;
}

void WiFiManager::poll() {
    cyw43_arch_poll();
}
