#include "hardware/flash.h"
#include "../include/bootloader.h"

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
    static bool flash(uint32_t flash_offs, const uint8_t *data, size_t count);
};
