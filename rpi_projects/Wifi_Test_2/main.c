#define LWIP_DNS 1
#define LWIP_SOCKET 1  // Optional, useful if you ever use sockets

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "pico/stdlib.h"
#include "pico/cyw43_arch.h"
#include "hardware/i2c.h"
#include "lwip/dns.h"

#include "./ssd1306.h"
#include "./example/image.h"
#include "./example/acme_5_outlines_font.h"
#include "./example/bubblesstandard_font.h"
#include "./example/crackers_font.h"
#include "./example/BMSPA_font.h"

const uint8_t num_chars_per_disp[] = {7, 7, 7, 5};
const uint8_t *fonts[4] = {acme_font, bubblesstandard_font, crackers_font, BMSPA_font};

#define SLEEPTIME 25

#ifndef WIFI_SSID
#define WIFI_SSID "default"
#endif

#ifndef WIFI_PASSWORD
#define WIFI_PASSWORD "default"
#endif

#define WIFI_CONNECT_RETRIES 5
#define WIFI_RETRY_DELAY_MS 3000

void setup_gpios(void);
void animation(const char *message);
bool connect_to_wifi(void);
bool test_connectivity(void);

int main()
{
    stdio_init_all();

    printf("Configuring Pins...\n");
    setup_gpios();

    printf("initializing Wi-Fi...\n");
    if (cyw43_arch_init_with_country(CYW43_COUNTRY_USA)) {
        printf("❌ CYW43 init failed!\n");
        animation("Wi-Fi Init Failed");
        return 1;
    } else {
        printf("✅ CYW43 init OK!\n");
    }

    dns_init();

    if (connect_to_wifi())
    {
        if (test_connectivity()) {
            animation("Internet is OK!");
        } else {
            animation("No Internet!");
        }
    } else {
        animation("Wi-Fi Failed!");
    }

    return 0;
}

bool resolved = false;

void dns_callback(const char *name, const ip_addr_t *ipaddr, void *arg) {
    if (ipaddr != NULL) {
        printf("✅ DNS callback: %s resolved to %s\n", name, ipaddr_ntoa(ipaddr));
        *((bool *)arg) = true;
    } else {
        printf("❌ DNS callback: failed to resolve %s\n", name);
        *((bool *)arg) = false;
    }
}

bool connect_to_wifi(void)
{
    cyw43_arch_enable_sta_mode();

    struct netif *netif = netif_default;

    for (int attempt = 1; attempt <= WIFI_CONNECT_RETRIES; attempt++)
    {
        printf("🌐 Attempt %d to connect...\n", attempt);
        printf("Connecting to SSID: %s\n", WIFI_SSID);
        printf("Using Password: %s\n", WIFI_PASSWORD);
        int result = cyw43_arch_wifi_connect_timeout_ms(
            WIFI_SSID, WIFI_PASSWORD, CYW43_AUTH_WPA2_AES_PSK, 20000);

        if (result == 0)
        {
            printf("✅ Connected to Wi-Fi. Requesting DHCP lease...\n");

            // Bring interface up
            netif_set_up(netif);

            // Start DHCP
            dhcp_start(netif);

            // Wait for DHCP to assign an IP address
            uint32_t start = to_ms_since_boot(get_absolute_time());
            while (!dhcp_supplied_address(netif)) {
                if (to_ms_since_boot(get_absolute_time()) - start > 10000) {
                    printf("❌ DHCP timeout.\n");
                    return false;
                }
                sleep_ms(500);
            }

            printf("✅ Got IP via DHCP: %s\n", ipaddr_ntoa(&netif->ip_addr));
            return true;
        }
        else
        {
            printf("❌ Failed to connect. Error: %d\n", result);
            sleep_ms(WIFI_RETRY_DELAY_MS);
        }
    }

    return false;
}


bool test_connectivity(void) {
    ip_addr_t addr;
    err_t err = dns_gethostbyname("google.com", &addr, dns_callback, &resolved);

    if (err == ERR_OK) {
        printf("✅ DNS resolved immediately: %s\n", ipaddr_ntoa(&addr));
        return true;
    } else if (err == ERR_INPROGRESS) {
        printf("ℹ️ Waiting for DNS resolution via callback...\n");

        // Wait for up to 5 seconds (or whatever fits your use case)
        for (int i = 0; i < 100 && !resolved; i++) {
            cyw43_arch_poll();  // Let lwIP run
            sleep_ms(50);
        }

        return resolved;
    } else {
        printf("❌ DNS resolution failed immediately (err=%d)\n", err);
        return false;
    }
}

void setup_gpios(void)
{
    i2c_init(i2c1, 400000);
    gpio_set_function(2, GPIO_FUNC_I2C);
    gpio_set_function(3, GPIO_FUNC_I2C);
    gpio_pull_up(2);
    gpio_pull_up(3);
}

void animation(const char *message)
{
    ssd1306_t disp;
    disp.external_vcc = false;
    ssd1306_init(&disp, 128, 64, 0x3C, i2c1);
    ssd1306_clear(&disp);

    printf("ANIMATION START: %s\n", message);

    int char_width = 12;
    int msg_width = strlen(message) * char_width;
    int x = 128;

    while (true)
    {
        ssd1306_clear(&disp);
        ssd1306_draw_string(&disp, x, 24, 2, message);
        ssd1306_show(&disp);
        sleep_ms(50);

        x -= 2;

        if (x < -msg_width)
        {
            x = 128;
        }
    }
}
