#include "lwip/tcp.h"
#include "hardware/flash.h"

#define FLASH_OFFSET(addr) ((addr) - XIP_BASE)
#define FLASH_BUFFER_SIZE FLASH_SECTOR_SIZE

#define OTA_BOOTLOADER_SIZE (FLASH_SECTOR_SIZE * 100) // 400 KB
#define OTA_FLAG_SIZE FLASH_SECTOR_SIZE                // 4 KB

#define OTA_FLAG_OFFSET (XIP_BASE + OTA_BOOTLOADER_SIZE)   // 0x10064000
#define OTA_WRITE_OFFSET (OTA_FLAG_OFFSET + OTA_FLAG_SIZE) // 0x10065000

struct FlashSession {
    size_t flash_offset;     // cumulative offset in flash
    size_t buffered;         // current number of bytes in RAM buffer
    bool skipping_headers;   // current TCP parse state
};

struct OTASession {
    FlashSession flash_session;
    const char* path;
};

class FlashManager {
public:
    static bool handle(tcp_pcb* tpcb, pbuf* p, err_t err, FlashSession* ctx);
    static err_t tcp_trampoline(void* arg, tcp_pcb* tpcb, pbuf* p, err_t err);
    static bool flash(uint32_t flash_addr);
    static bool store(uint32_t flash_addr, const uint8_t* data, size_t len);
};
