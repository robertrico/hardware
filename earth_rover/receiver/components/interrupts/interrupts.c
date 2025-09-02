#include "include.h"
#include "interrupts.h"
#include "rom/ets_sys.h"

void IRAM_ATTR vButtonReceive(const esp_now_recv_info_t* info, const uint8_t* data, int len) {
    static uint32_t isr_count = 0;
    isr_count++;
    
    // Quick debug print from ISR (normally not recommended but useful for debugging)
    ets_printf("[ISR %lu] ESP-NOW packet received, len=%d\n", isr_count, len);
    
    uint8_t payload[16];
    int copy_len = (len < (int)sizeof(payload)) ? len : (int)sizeof(payload);
    memcpy(payload, data, copy_len);

    // Send data to main task for processing
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;
    xQueueSendFromISR(rdySem, payload, &xHigherPriorityTaskWoken);
    
    if (xHigherPriorityTaskWoken) {
        portYIELD_FROM_ISR();
    }
}
