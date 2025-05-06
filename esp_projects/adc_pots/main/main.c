#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "esp_adc/adc_oneshot.h"

#define LED_GPIO        GPIO_NUM_21
#define POT_ADC_CH      ADC_CHANNEL_4  // GPIO0

void app_main(void)
{
    // Setup LED output
    gpio_config_t io_conf = {
        .pin_bit_mask = (1ULL << LED_GPIO),
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = 0,
        .pull_down_en = 0,
        .intr_type = GPIO_INTR_DISABLE
    };
    gpio_config(&io_conf);
    gpio_pullup_dis(GPIO_NUM_0);       // disable pull-up
    gpio_pulldown_en(GPIO_NUM_0);      // enable pull-down
    // Setup ADC oneshot driver
    adc_oneshot_unit_handle_t adc_handle;
    adc_oneshot_unit_init_cfg_t init_cfg = {
        .unit_id = ADC_UNIT_1
    };
    adc_oneshot_new_unit(&init_cfg, &adc_handle);

    adc_oneshot_chan_cfg_t chan_cfg = {
        .bitwidth = ADC_BITWIDTH_DEFAULT,   // Default 12-bit
        .atten = ADC_ATTEN_DB_12           // for 0-3.3V input
    };
    adc_oneshot_config_channel(adc_handle, POT_ADC_CH, &chan_cfg);

    while (1) {
        int val = 0;
        printf("Reading ADC value...\n");
        adc_oneshot_read(adc_handle, POT_ADC_CH, &val);
        printf("ADC value: %d\n", val);

        if (val < 700) {
            printf("ADC value is low\n");
            gpio_set_level(LED_GPIO, 1);
        } else if (val > 3000) {
            printf("ADC value is high\n");
            gpio_set_level(LED_GPIO, 1);
        } else {
            printf("ADC value is normal\n");
            gpio_set_level(LED_GPIO, 0);
        }

        vTaskDelay(pdMS_TO_TICKS(100));
    }
}
