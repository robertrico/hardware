#include "wifi_manager.hpp"
#include "pico/stdlib.h"
#include "lwip/dns.h"
#include "lwip/dhcp.h"
#include "lwip/netif.h"
#include <cstdio>
#include "hardware/i2c.h"       // for i2c_init and i2c1
#include "lwip/tcp.h"           // for tcp_new, tcp_connect, tcp_write, etc.
#include "lwip/pbuf.h"          // for pbuf_free
#include "lwip/ip_addr.h"       // for ip4addr_aton
#include <string.h>             // for memcpy, strtok, strchr

#define WIFI_CONNECT_RETRIES 5
#define WIFI_RETRY_DELAY_MS 3000

static bool resolved = false;

static void dns_callback(const char *name, const ip_addr_t *ipaddr, void *arg) {
    if (ipaddr) {
        printf("DNS callback: %s resolved to %s\n", name, ipaddr_ntoa(ipaddr));
        *(bool *)arg = true;
    } else {
        printf("DNS callback: failed to resolve %s\n", name);
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
        printf("Attempt %d to connect...\n", attempt);
        int result = cyw43_arch_wifi_connect_timeout_ms(
            WIFI_SSID, WIFI_PASSWORD, CYW43_AUTH_WPA2_AES_PSK, 20000);

        if (result == 0) {
            printf("Connected. Starting DHCP...\n");
            netif_set_up(netif);
            dhcp_start(netif);

            uint32_t start = to_ms_since_boot(get_absolute_time());
            while (!dhcp_supplied_address(netif)) {
                if (to_ms_since_boot(get_absolute_time()) - start > 10000) {
                    printf("DHCP timeout.\n");
                    return false;
                }
                sleep_ms(500);
            }

            printf("Got IP: %s\n", ipaddr_ntoa(&netif->ip_addr));
            return true;
        }

        printf("Failed to connect. Retrying...\n");
        sleep_ms(WIFI_RETRY_DELAY_MS);
    }

    return false;
}

bool WiFiManager::testConnectivity() {
    ip_addr_t ip;
    ip4addr_aton("3.19.70.134", &ip);

    struct tcp_pcb *pcb = tcp_new();
    if (!pcb) {
        printf("Failed to allocate PCB\n");
        return false;
    }

    static char response_buf[512];  // Large enough for single response line
    static int response_len = 0;
    memset(response_buf, 0, sizeof(response_buf));
    
    tcp_recv(pcb, [](void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err) -> err_t {
        if (!p) {
            printf("Connection closed by server.\n");
            tcp_close(tpcb);
            return ERR_OK;
        }
    
        if (response_len + p->tot_len < sizeof(response_buf)) {
            pbuf_copy_partial(p, response_buf + response_len, p->tot_len, 0);
            response_len += p->tot_len;
            response_buf[response_len] = '\0'; // Always null-terminate
        } else {
            printf("❌ Response too large\n");
        }
    
        tcp_recved(tpcb, p->tot_len);
        pbuf_free(p);
        return ERR_OK;
    });

    tcp_connect(pcb, &ip, 8081, [](void *arg, struct tcp_pcb *tpcb, err_t err) -> err_t {
        const char req[] = "GET / HTTP/1.0\r\nHost: 3.19.70.134\r\n\r\n";
        tcp_write(tpcb, req, strlen(req), TCP_WRITE_FLAG_COPY);
        return ERR_OK;
    });

    for (int i = 0; i < 100; ++i) {
        cyw43_arch_poll();
        sleep_ms(50);
    }

    char* body = strstr(response_buf, "\r\n\r\n");
    
    if (body) {
        body += 4;
        printf("Raw Response: %s\n", response_buf);
    
        // 🔧 NEW: Find the start of the body after \r\n\r\n
        char* body = strstr(response_buf, "\r\n\r\n");
        if (body) {
            body += 4;  // skip past the delimiter
            printf("Body: %s\n", body);
    
            // Parse body key=value;key2=value2;
            char* token = strtok(body, ";");
            while (token) {
                char* eq = strchr(token, '=');
                if (eq) {
                    *eq = '\0';
                    const char* key = token;
                    const char* value = eq + 1;
                    printf("KEY = %s | VALUE = %s\n", key, value);
                }
                token = strtok(NULL, ";");
            }
            return true;
        } else {
            printf("No valid body found in response.\n");
        }
    }

    printf("No response received\n");
    return false;
}



void WiFiManager::poll() {
    cyw43_arch_poll();
}
