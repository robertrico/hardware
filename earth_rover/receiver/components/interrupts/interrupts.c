#include "include.h"
#include "interrupts.h"
#include <rom/ets_sys.h>

void vSendSPI(uint8_t* payload) {
    esp_err_t errorStatus;
    static int interruptCount = 0;

    uint8_t sendBuffer[4];
    sendBuffer[0] = payload[0]; // bx low byte
    sendBuffer[1] = payload[1]; // bx high byte
    sendBuffer[2] = payload[2]; // by low byte
    sendBuffer[3] = payload[3]; // by high byte
    uint8_t receiveBuffer[4] = {0,0,0,0};

    spi_transaction_t spiTransaction;
    memset(&spiTransaction,0,sizeof(spiTransaction));

    spiTransaction.length = 8 * 4;
    spiTransaction.tx_buffer = sendBuffer;
    spiTransaction.rx_buffer = receiveBuffer;

    uint16_t bx = payload[0] | (payload[1] << 8);
    uint16_t by = payload[2] | (payload[3] << 8);
    ESP_LOGI("RX", "Sending: bx %d, by %d", bx, by);

    gpio_set_level(GPIO_CS, 0);
    ets_delay_us(20);
    errorStatus = spi_device_transmit(spiDeviceHandle, &spiTransaction);
    gpio_set_level(GPIO_CS, 1);
    if (errorStatus != ESP_OK) {
        ESP_LOGE("SPI", "spi_device_transmit failed: %d", errorStatus);
    }
}

void IRAM_ATTR vButtonReceive(const esp_now_recv_info_t* info, const uint8_t* data, int len) {
    uint8_t payload[16]; // Adjust size as needed
    int copy_len = (len < (int)sizeof(payload) - 1) ? len : (int)sizeof(payload) - 1;
    memcpy(payload, data, copy_len);
    payload[copy_len] = '\0';

    // ESP_LOGI("RX", "Received payload: %d", payload);
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;
    xQueueSendFromISR(rdySem, payload, &xHigherPriorityTaskWoken);
}
