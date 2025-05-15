#define LWIP_DNS 1
#define LWIP_SOCKET 1  // Optional, useful if you ever use sockets

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "pico/stdlib.h"
#include "pico/cyw43_arch.h"
#include "hardware/i2c.h"
#include "lwip/dns.h"
#include "lwip/tcp.h"

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
bool connect_to_wifi(void);
bool test_connectivity(void);
void get_request(const char* hostname, ip_addr_t *ipaddr, uint16_t port);
void dns_callback(const char *name, const ip_addr_t *ipaddr, void *arg);

bool resolved = false;

int main()
{
    stdio_init_all();

    printf("Configuring Pins...\n");
    setup_gpios();

    printf("initializing Wi-Fi...\n");
    if (cyw43_arch_init_with_country(CYW43_COUNTRY_USA)) {
        printf("❌ CYW43 init failed!\n");
        printf("Wi-Fi Init Failed");
        return 1;
    } else {
        printf("✅ CYW43 init OK!\n");
    }

    dns_init();

    if (connect_to_wifi())
    {
        if (test_connectivity()) {
            printf("Internet is OK!\n");

            ip_addr_t ipaddr;
            err_t err = dns_gethostbyname("example.com", &ipaddr, dns_callback, &resolved);

            if (err == ERR_OK) {
                printf("✅ DNS resolved immediately: %s\n", ipaddr_ntoa(&ipaddr));
                get_request("example.com", &ipaddr, 80);
            } else if (err == ERR_INPROGRESS) {
                printf("Waiting for DNS resolution...\n");
                while (!resolved) {
                    cyw43_arch_poll();
                    sleep_ms(50);
                }
                if (resolved) {
                    //dns_gethostbyname("example.com", &ipaddr, NULL, NULL);  // should now resolve immediately
                    dns_gethostbyname("3.19.70.134", &ipaddr, NULL, NULL);  // should now resolve immediately
                    get_request("3.19.70.134", &ipaddr, 8081);
                } else {
                    printf("DNS resolution failed.\n");
                }
            } else {
                printf("DNS resolution failed immediately (err=%d)\n", err);
            }

            // Wait for response handling
            for (int i = 0; i < 100; i++) {
                cyw43_arch_poll();
                sleep_ms(100);
            }

        } else {
            printf("No Internet!\n");
        }
    } else {
        printf("Wi-Fi Failed!\n");
    }

    return 0;
}


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

static err_t recv_callback(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err)
{
    if (!p) {
        printf("Connection closed by remote host.\n");
        tcp_close(tpcb);
        return ERR_OK;
    }

    printf("Received %d bytes:\n", p->tot_len);
    fwrite(p->payload, 1, p->len, stdout);
    printf("\n");

    tcp_recved(tpcb, p->tot_len);
    pbuf_free(p);
    tcp_close(tpcb);
    return ERR_OK;
}

static err_t connect_callback(void *arg, struct tcp_pcb *tpcb, err_t err)
{
    const char request[] = "GET / HTTP/1.0\r\nHost: 3.19.70.134\r\n\r\n";
    tcp_write(tpcb, request, strlen(request), TCP_WRITE_FLAG_COPY);
    return ERR_OK;
}

void get_request(const char* hostname, ip_addr_t *ipaddr, uint16_t port)
{
    printf("Starting GET request to %s...\n", hostname);

    struct tcp_pcb *pcb = tcp_new();
    if (!pcb) {
        printf("Failed to create new PCB\n");
        return;
    }

    tcp_recv(pcb, recv_callback);
    tcp_connect(pcb, ipaddr, port, connect_callback);
}