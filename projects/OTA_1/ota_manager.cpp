#include "ota_manager.hpp"
#include "pico/stdlib.h"
#include "lwip/apps/http_client.h"
#include "lwip/dns.h"
#include "lwip/ip_addr.h"
#include "hardware/flash.h"
#include <string>
#include <cstring>
#include <cstdio>
#include "version.h"
#include "pico/cyw43_arch.h"

static constexpr const char* OTA_SERVER_IP = "3.128.180.81"; // Change to your Mac IP
static constexpr uint16_t OTA_SERVER_PORT = 8081;
static constexpr const char* OTA_META_PATH = "/";

bool OTAManager::checkForUpdate() {
    ip_addr_t server_ip;
    ip4addr_aton(OTA_SERVER_IP, &server_ip);

    struct tcp_pcb *pcb = tcp_new();
    if (!pcb) {
        printf("Failed to allocate TCP PCB\n");
        return false;
    }

    static char response_buf[1024] = {0};
    static int response_len = 0;

    tcp_recv(pcb, [](void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err) -> err_t {
        if (!p) {
            tcp_close(tpcb);
            return ERR_OK;
        }

        response_len += pbuf_copy_partial(p, response_buf + response_len, p->tot_len, 0);
        response_buf[response_len] = '\0';
        tcp_recved(tpcb, p->tot_len);
        pbuf_free(p);
        return ERR_OK;
    });

    tcp_connect(pcb, &server_ip, OTA_SERVER_PORT, [](void *arg, struct tcp_pcb *tpcb, err_t err) -> err_t {

        std::string req = std::string("GET ") + OTA_META_PATH + " HTTP/1.1\r\nHost: ";
        req += OTA_SERVER_IP;
        req += "\r\n\r\n";
        tcp_write(tpcb, req.c_str(), req.size(), TCP_WRITE_FLAG_COPY);
        return ERR_OK;
    });

    for (int i = 0; i < 100; ++i) {
        cyw43_arch_poll();
        sleep_ms(50);
    }

    // Locate and extract JSON body
    char* body = strstr(response_buf, "\r\n\r\n");
    if (!body) {
        printf("No HTTP body found.\n");
        return false;
    }

    body += 4;
    printf("OTA metadata: %s\n", body);

    // Very naive JSON parsing (no dependency)
    const char* version_key = "\"version\":";
    char* vloc = strstr(body, version_key);
    if (!vloc) return false;

    char* quote1 = strchr(vloc, '\"');
    if (!quote1) return false;
    char* quote2 = strchr(quote1 + 1, '\"');
    if (!quote2) return false;
    char* quote3 = strchr(quote2 + 1, '\"');
    if (!quote3) return false;
    char* quote4 = strchr(quote3 + 1, '\"');
    if (!quote4) return false;

    char incoming_version[16] = {0};
    memcpy(incoming_version, quote3 + 1, quote4 - quote3 - 1);
    incoming_version[quote4 - quote3 - 1] = '\0';

    printf("Current: %s | Incoming: %s\n", VERSION, incoming_version);
    return strcmp(VERSION, incoming_version) != 0;
}
