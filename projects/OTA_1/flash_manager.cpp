#include "flash_manager.hpp"
#include "pico/stdlib.h"
#include "hardware/flash.h"
#include "hardware/sync.h"
#include "lwip/tcp.h" // for tcp_new, tcp_connect, tcp_write, etc.
#include <cstdint>
#include <cstdio>
#include <cstring> // for memcpy, strtok, strchr

__attribute__((section(".ram_flash_buffer")))
__attribute__((used))
uint8_t ram_flash_buffer[FLASH_SECTOR_SIZE];

// Trampoline function to handle TCP events
err_t FlashManager::tcp_trampoline(void *arg, tcp_pcb *tpcb, pbuf *p, err_t err)
{
    OTASession* ctx = static_cast<OTASession*>(arg);
    if (!p)
    {
        tcp_close(tpcb);
        return ERR_OK;
    }
    
    return FlashManager::handle(tpcb, p, err, &(ctx->flash_session));
}

bool FlashManager::flash(uint32_t flash_addr)
{
    uint32_t ints = save_and_disable_interrupts();

    printf("Flashing to address: 0x%06X\n", flash_addr);
    flash_range_erase(FLASH_OFFSET(flash_addr), FLASH_SECTOR_SIZE);
    flash_range_program(FLASH_OFFSET(flash_addr), ram_flash_buffer, FLASH_SECTOR_SIZE);

    restore_interrupts(ints);

    // Clear the buffer after writing
    memset(ram_flash_buffer, 0, FLASH_SECTOR_SIZE);

    return true;
}

bool FlashManager::handle(tcp_pcb *tpcb, pbuf *p, err_t err, FlashSession *ctx)
{

    static bool skipping_headers = true;

    uint8_t *data = (uint8_t *)p->payload;
    size_t len = p->len;

    // Skip HTTP headers
    if (skipping_headers) {
        char *body_start = strstr((char *)data, "\r\n\r\n");
        if (body_start) {
            size_t header_len = body_start + 4 - (char *)data;
            data += header_len;
            len -= header_len;
            skipping_headers = false;
        } else {
            tcp_recved(tpcb, p->len);
            pbuf_free(p);
            return ERR_OK;
        }
    }

    while (len > 0) {
        size_t space_left = FLASH_SECTOR_SIZE - ctx->buffered;
        size_t chunk = (len < space_left) ? len : space_left;
    
        memcpy(ram_flash_buffer + ctx->buffered, data, chunk);
        ctx->buffered += chunk;
        data += chunk;
        len -= chunk;
    
        if (ctx->buffered == FLASH_SECTOR_SIZE) {
            gpio_put(16, 1);
            FlashManager::flash(ctx->flash_offset);  // you'll want to track this externally
            ctx->flash_offset += FLASH_SECTOR_SIZE;
            ctx->buffered = 0;
        }
        gpio_put(16, 0);
    }

    tcp_recved(tpcb, p->len);
    pbuf_free(p);
    return ERR_OK;
}

bool FlashManager::store(uint32_t flash_addr, const uint8_t *data, size_t len)
{
    if (len > FLASH_SECTOR_SIZE) {
        printf("Error: Data length exceeds flash sector size.\n");
        return false;
    }

    // Copy data to the flash buffer
    memset(ram_flash_buffer, 0, FLASH_SECTOR_SIZE); // Clear the buffer
    memcpy(ram_flash_buffer, data, len);

    return FlashManager::flash(flash_addr); // Call the flash function
}