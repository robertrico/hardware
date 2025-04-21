#include "ota_manager.hpp"
#include "flash_manager.hpp"
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
#include "pico/stdlib.h"
#include "hardware/structs/scb.h"

static constexpr const char *OTA_SERVER_IP = "3.128.180.81"; // Change to your Mac IP
static constexpr uint16_t OTA_SERVER_PORT = 8081;
static constexpr const char *OTA_META_PATH = "/";
static constexpr const char *OTA_FIRMWARE_PATH = "/ota/firmware_*version*.php";

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

    tcp_recv(pcb,
        [](void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err) -> err_t {
            if (!p) {
                tcp_close(tpcb);
                return ERR_OK;
            }

            response_len += pbuf_copy_partial(p, response_buf + response_len, p->tot_len, 0);
            response_buf[response_len] = '\0';
            tcp_recved(tpcb, p->tot_len);
            pbuf_free(p);
            return ERR_OK;
        }
    );

    tcp_connect(pcb, &server_ip, OTA_SERVER_PORT,
        [](void *arg, struct tcp_pcb *tpcb, err_t err) -> err_t {

        std::string req = std::string("GET ") + OTA_META_PATH + " HTTP/1.1\r\nHost: ";
        req += OTA_SERVER_IP;
        req += "\r\n\r\n";

        tcp_write(tpcb, req.c_str(), req.size(), TCP_WRITE_FLAG_COPY);
            return ERR_OK;
        }
    );

    // Poll the Wi-Fi stack and wait for the TCP connection to complete
    for (int i = 0; i < 100; ++i) {
        cyw43_arch_poll();
        sleep_ms(50);
    }

    // Locate and extract JSON body
    char *body = strstr(response_buf, "\r\n\r\n");
    if (!body) {
        printf("No HTTP body found.\n");
        return false;
    }

    body += 4; // Skip the "\r\n\r\n" to point to the start of the HTTP body content
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
    OTASession* ctx = static_cast<OTASession*>(arg);

    std::string req = "GET ";
    req += ctx->path;
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

    if (version_pos != std::string::npos) {
        firmware_path.replace(version_pos, 9, "v1_01");
    }

    memcpy(ipbuf, OTA_SERVER_IP, strlen(OTA_SERVER_IP)); // Use OTA_SERVER_IP directly

    const char *path = firmware_path.c_str();
    ip_addr_t server_ip;
    ip4addr_aton(ipbuf, &server_ip);

    struct tcp_pcb *pcb = tcp_new();

    FlashSession flash_ctx = {
        .flash_offset = OTA_WRITE_OFFSET,
        .buffered = 0,
        .skipping_headers = true,
    };

    if (!pcb) {
        printf("Failed to create TCP PCB\n");
        return false;
    }

    OTASession ota_session = {
        .flash_session = flash_ctx,
        .path = (char *)path,
    };

    tcp_recv(pcb, &FlashManager::tcp_trampoline);
        
    tcp_arg(pcb, &ota_session);

    tcp_connect(pcb, &server_ip, 8081, on_tcp_connected);

    for (int i = 0; i < 200; ++i) {
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

    FlashManager::store(OTA_FLAG_OFFSET, flash_buf, sizeof(boot_flag));

    return true;
}

bool OTAManager::checkBootFlag(char *out_version)
{
    const uint8_t *flag_ptr = (const uint8_t *)(OTA_FLAG_OFFSET);

    BootFlag *flag = (BootFlag *)flag_ptr;

    if (memcmp(flag->magic, "BOOT", 4) != 0)
    {
        return false;
    }

    if (out_version)
    {
        memcpy(out_version, flag->version, sizeof(flag->version));
        out_version[sizeof(flag->version)] = '\0'; // Ensure null termination
    }

    return true;
}

bool OTAManager::clearBootFlag()
{
    uint32_t ints = save_and_disable_interrupts();
    flash_range_erase(FLASH_OFFSET(OTA_FLAG_OFFSET), OTA_FLAG_SIZE);
    restore_interrupts(ints);
    return true;
}

void OTAManager::jumpToB()
{

    // In an assembly snippet . . .
    // Set VTOR register, set stack pointer, and jump to reset
    asm volatile (
        "mov r0, %[start]\n"
        "ldr r1, =%[vtable]\n"
        "str r0, [r1]\n"
        "ldmia r0, {r0, r1}\n"
        "msr msp, r0\n"
        "bx r1\n"
        :
        : [start] "r" (OTA_WRITE_OFFSET), [vtable] "X" (PPB_BASE + M0PLUS_VTOR_OFFSET)
        :
        );
}
