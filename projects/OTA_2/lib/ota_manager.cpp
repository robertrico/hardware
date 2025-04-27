#include "ota_manager.hpp"
#include "flash_manager.hpp"
#include "../include/bootloader.h"
#include "hardware/watchdog.h"
#include <RP2040.h>

static constexpr const char *OTA_SERVER_IP = "3.128.180.81"; // Change to your Mac IP
static constexpr uint16_t OTA_SERVER_PORT = 8081;
static constexpr const char *OTA_META_PATH = "/";
static constexpr const char *OTA_FIRMWARE_PATH = "/ota/firmware_*version*.php";

void OTAManager::checkForUpdate()
{
    BootConfig boot_config = boot_config_flash;

    printf("Current version: %s\n", boot_config.version);
    printf("Flash app start: 0x%08X\n", boot_config.flash_app_start);
    printf("Bootloader mode: %s\n", boot_config.mode);
    printf("Bootloader magic: 0x%08X\n", boot_config.magic);

    char version[8] = "1.0.2";
    OTAManager::updateBootConfig(version);
    OTAManager::downloadAndWrite();

    // Watchdog reset
    watchdog_enable(1, 1);
    while (1)
        ;
}

bool OTAManager::updateBootConfig(const char *version)
{
    BootConfig new_config = boot_config_flash; // Start with current config
    printf("Firmware Slot: %08X\n", BOOT_CONFIG_START);

    // Update the version
    memset(new_config.version, 0, 8);
    memcpy(new_config.version, version, 8);

    // Set mode to RUN
    memset(new_config.mode, 0, 5);
    memcpy(new_config.mode, "_RUN", 5);

    printf("Dowloaded version: %s\n", new_config.version);
    bool ret = FlashManager::flash(BOOT_CONFIG_START, (const uint8_t*)&new_config, FLASH_SECTOR_SIZE);
    
    return ret;
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
        .flash_offset = FLASH_APP_START,
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

    printf("Starting firmware writes...\n");
    tcp_recv(pcb, &FlashManager::tcp_trampoline);
        
    tcp_arg(pcb, &ota_session);

    tcp_connect(pcb, &server_ip, 8081, on_tcp_connected);

    for (int i = 0; i < 200; ++i) {
        cyw43_arch_poll();
        gpio_put(LED_YLW, 1);
        sleep_ms(50);
    }

    printf("Firmware written to offset 0x%06X\n", FLASH_APP_START);
    return true;
}
static void _disable_interrupts(void) {
    SysTick->CTRL &= ~1;

    NVIC->ICER[0] = 0xFFFFFFFF;
    NVIC->ICPR[0] = 0xFFFFFFFF;
}

static void reset_peripherals(void) {
    reset_block(~(RESETS_RESET_IO_QSPI_BITS | RESETS_RESET_PADS_QSPI_BITS
                  | RESETS_RESET_SYSCFG_BITS | RESETS_RESET_PLL_SYS_BITS));
}

void OTAManager::jumpToB() {
    // Derived from the Leaf Labs Cortex-M3 bootloader.
    // Copyright (c) 2010 LeafLabs LLC.
    // Modified 2021 Brian Starkey <stark3y@gmail.com>
    // Originally under The MIT License

    uint32_t reset_vector = *(volatile uint32_t *) (FLASH_APP_START + 0x04);
    SCB->VTOR = (volatile uint32_t)(FLASH_APP_START);

    asm volatile("cpsid i");

    asm volatile("msr msp, %0" ::"g"(*(volatile uint32_t *) (FLASH_APP_START)));

    asm volatile("bx %0" ::"r"(reset_vector));
}

char* OTAManager::checkBootFlag()
{
    const uint8_t *flag_ptr = (const uint8_t *)(BOOT_CONFIG_START);

    BootConfig *boot_config = (BootConfig *)flag_ptr;

    return boot_config->mode;
}

/*
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


bool OTAManager::clearBootFlag()
{
    uint32_t ints = save_and_disable_interrupts();
    flash_range_erase(FLASH_OFFSET(OTA_FLAG_OFFSET), OTA_FLAG_SIZE);
    restore_interrupts(ints);
    return true;
}

*/
