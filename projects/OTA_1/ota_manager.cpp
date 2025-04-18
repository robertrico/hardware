#include "ota_manager.hpp"
#include "pico/stdlib.h"
#include "pico/cyw43_arch.h"
#include "lwip/tcp.h"
#include "lwip/apps/http_client.h"
#include "lwip/dns.h"
#include "lwip/ip_addr.h"
#include "hardware/flash.h"
#include "hardware/sync.h"
#include "version.h"
#include <string>
#include <cstring>
#include <cstdio>

#define OTA_WRITE_OFFSET (0x0C0000) // Firmware B region
#define OTA_FLASH_SECTOR_SIZE 4096  // Minimum erase/write size

#define OTA_FLAG_OFFSET 0x140000
#define OTA_FLAG_SIZE 12

static constexpr const char *OTA_SERVER_IP = "3.128.180.81"; // Change to your Mac IP
static constexpr uint16_t OTA_SERVER_PORT = 8081;
static constexpr const char *OTA_META_PATH = "/";
static constexpr const char *OTA_FIRMWARE_PATH = "/ota/firmware_*version*.bin";

bool OTAManager::checkForUpdate()
{
    ip_addr_t server_ip;
    ip4addr_aton(OTA_SERVER_IP, &server_ip);

    struct tcp_pcb *pcb = tcp_new();
    if (!pcb)
    {
        printf("Failed to allocate TCP PCB\n");
        return false;
    }

    static char response_buf[1024] = {0};
    static int response_len = 0;

    tcp_recv(pcb, [](void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err) -> err_t
             {
        if (!p) {
            tcp_close(tpcb);
            return ERR_OK;
        }

        response_len += pbuf_copy_partial(p, response_buf + response_len, p->tot_len, 0);
        response_buf[response_len] = '\0';
        tcp_recved(tpcb, p->tot_len);
        pbuf_free(p);
        return ERR_OK; });

    tcp_connect(pcb, &server_ip, OTA_SERVER_PORT, [](void *arg, struct tcp_pcb *tpcb, err_t err) -> err_t
                {

        std::string req = std::string("GET ") + OTA_META_PATH + " HTTP/1.1\r\nHost: ";
        req += OTA_SERVER_IP;
        req += "\r\n\r\n";
        tcp_write(tpcb, req.c_str(), req.size(), TCP_WRITE_FLAG_COPY);
        return ERR_OK; });

    for (int i = 0; i < 100; ++i)
    {
        cyw43_arch_poll();
        sleep_ms(50);
    }

    // Locate and extract JSON body
    char *body = strstr(response_buf, "\r\n\r\n");
    if (!body)
    {
        printf("No HTTP body found.\n");
        return false;
    }

    body += 4;
    printf("OTA metadata: %s\n", body);

    // Very naive JSON parsing (no dependency)
    const char *version_key = "\"version\":";
    char *vloc = strstr(body, version_key);
    if (!vloc)
        return false;

    char *quote1 = strchr(vloc, '\"');
    if (!quote1)
        return false;
    char *quote2 = strchr(quote1 + 1, '\"');
    if (!quote2)
        return false;
    char *quote3 = strchr(quote2 + 1, '\"');
    if (!quote3)
        return false;
    char *quote4 = strchr(quote3 + 1, '\"');
    if (!quote4)
        return false;

    char incoming_version[16] = {0};
    memcpy(incoming_version, quote3 + 1, quote4 - quote3 - 1);
    incoming_version[quote4 - quote3 - 1] = '\0';

    printf("Current: %s | Incoming: %s\n", VERSION, incoming_version);
    return strcmp(VERSION, incoming_version) != 0;
}

static err_t on_tcp_connected(void *arg, struct tcp_pcb *tpcb, err_t err)
{
    const char *path = (const char *)arg;

    std::string req = "GET ";
    req += path;
    req += " HTTP/1.1\r\nHost: 3.128.180.81\r\n\r\n"; // hardcode or pass later
    tcp_write(tpcb, req.c_str(), req.size(), TCP_WRITE_FLAG_COPY);

    return ERR_OK;
}

bool OTAManager::downloadAndWrite()
{
    printf("Starting firmware download...\n");

    // Extract IP
    char ipbuf[32] = {0};
    std::string firmware_path = OTA_FIRMWARE_PATH;
    size_t version_pos = firmware_path.find("*version*");
    if (version_pos != std::string::npos)
    {
        firmware_path.replace(version_pos, 9, "v1_01");
    }
    memcpy(ipbuf, OTA_SERVER_IP, strlen(OTA_SERVER_IP)); // Use OTA_SERVER_IP directly
    const char *path = firmware_path.c_str();

    ip_addr_t server_ip;
    ip4addr_aton(ipbuf, &server_ip);

    struct tcp_pcb *pcb = tcp_new();
    if (!pcb)
    {
        printf("Failed to create TCP PCB\n");
        return false;
    }

    static uint8_t flash_buf[OTA_FLASH_SECTOR_SIZE] = {0};
    static size_t flash_offset = 0;
    flash_offset = 0;

    tcp_recv(pcb, [](void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err) -> err_t
             {
        if (!p) {
            printf("Connection closed.\n");
            tcp_close(tpcb);
            return ERR_OK;
        }

        static bool skipping_headers = true;
        static size_t header_offset = 0;

        uint8_t* data = (uint8_t*)p->payload;
        size_t len = p->len;

        // Skip HTTP headers
        if (skipping_headers) {
            char* body_start = strstr((char*)data, "\r\n\r\n");
            if (body_start) {
                size_t header_len = body_start + 4 - (char*)data;
                data += header_len;
                len -= header_len;
                skipping_headers = false;
            } else {
                tcp_recved(tpcb, p->len);
                pbuf_free(p);
                return ERR_OK;
            }
        }

        // Align to flash sector writes
        while (len > 0) {
            size_t chunk = OTA_FLASH_SECTOR_SIZE - (flash_offset % OTA_FLASH_SECTOR_SIZE);
            if (chunk > len) chunk = len;

            memcpy(flash_buf, data, chunk);

            uint32_t flash_addr = OTA_WRITE_OFFSET + flash_offset;
            uint32_t ints = save_and_disable_interrupts();

            flash_range_erase(flash_addr, OTA_FLASH_SECTOR_SIZE);
            flash_range_program(flash_addr, flash_buf, chunk);

            restore_interrupts(ints);

            flash_offset += chunk;
            data += chunk;
            len -= chunk;
        }

        tcp_recved(tpcb, p->len);
        pbuf_free(p);
        return ERR_OK; });

    tcp_arg(pcb, (void *)path);
    tcp_connect(pcb, &server_ip, 8081, on_tcp_connected);

    for (int i = 0; i < 200; ++i)
    {
        cyw43_arch_poll();
        sleep_ms(50);
    }

    printf("Firmware written to offset 0x%06X\n", OTA_WRITE_OFFSET);
    return true;
}

bool OTAManager::switchToB(const char *version)
{
    BootFlag boot_flag;
    static_assert(sizeof(BootFlag) <= OTA_FLAG_SIZE, "BootFlag too large!");

    memcpy(boot_flag.magic, "BOOT", 4);
    memcpy(boot_flag.version, version, 8);

    static uint8_t flash_buf[OTA_FLAG_SIZE] = {0};

    memset(flash_buf, 0, OTA_FLAG_SIZE);
    memcpy(flash_buf, &boot_flag, sizeof(boot_flag));

    uint32_t flash_addr = OTA_FLAG_OFFSET;
    uint32_t ints = save_and_disable_interrupts();

    flash_range_erase(flash_addr, OTA_FLAG_SIZE);
    flash_range_program(flash_addr, flash_buf, sizeof(boot_flag));

    restore_interrupts(ints);

    return true;
}

bool OTAManager::checkBootFlag(char* out_version) {
    const uint8_t* flag_ptr = (const uint8_t*)(XIP_BASE + OTA_FLAG_OFFSET);

    BootFlag* flag = (BootFlag*)flag_ptr;
    
    for (int i = 0; i < 16; ++i) {
        printf("flash[%02d] = 0x%02X\n", i, ((uint8_t*)flag)[i]);
    }

    if (memcmp(flag->magic, "BOOT", 4) != 0) {
        return false;
    }

    if (out_version) {
        memcpy(out_version, flag->version, sizeof(flag->version));
        out_version[sizeof(flag->version)] = '\0'; // Ensure null termination
    }

    return true;
}

bool OTAManager::clearBootFlag() {
    uint32_t ints = save_and_disable_interrupts();
    flash_range_erase(OTA_FLAG_OFFSET, OTA_FLAG_SIZE);
    restore_interrupts(ints);
    return true;
}
