## Overview

This project demonstrates basic GPIO usage on the Raspberry Pi Pico using the Zephyr RTOS. Five LEDs are mapped and toggled in a forward, backward, and "dance" pattern using Zephyr's GPIO and DeviceTree abstractions.

This README captures the minimal working example, project structure, and key lessons learned for future reference.

---

## Hardware

- **Board**: Raspberry Pi Pico (RP2040 MCU)
    
- **LEDs**: 5x discrete LEDs connected to GPIO14, GPIO15, GPIO17, GPIO18, GPIO19
    

---

## Project Structure

```
samples/basic/blinky/
├── boards/
│   └── rpi_pico.overlay
├── src/
│   └── main.c
├── prj.conf
├── CMakeLists.txt
```

---

## DeviceTree Overlay: `boards/rpi_pico.overlay`

```dts
/ {
    leds {
        compatible = "gpio-leds";

        led_0: led_0 {
            gpios = <&gpio0 14 GPIO_ACTIVE_HIGH>;
            label = "LED 0";
        };
        led_1: led_1 {
            gpios = <&gpio0 15 GPIO_ACTIVE_HIGH>;
            label = "LED 1";
        };
        led_2: led_2 {
            gpios = <&gpio0 17 GPIO_ACTIVE_HIGH>;
            label = "LED 2";
        };
        led_3: led_3 {
            gpios = <&gpio0 18 GPIO_ACTIVE_HIGH>;
            label = "LED 3";
        };
        led_4: led_4 {
            gpios = <&gpio0 19 GPIO_ACTIVE_HIGH>;
            label = "LED 4";
        };
    };
};
```

---

## Application Code: `src/main.c`

```c
#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/devicetree.h>
#include <zephyr/drivers/gpio.h>

#define LED0_NODE DT_NODELABEL(led_0)
#define LED1_NODE DT_NODELABEL(led_1)
#define LED2_NODE DT_NODELABEL(led_2)
#define LED3_NODE DT_NODELABEL(led_3)
#define LED4_NODE DT_NODELABEL(led_4)

static const struct gpio_dt_spec leds[] = {
    GPIO_DT_SPEC_GET(LED0_NODE, gpios),
    GPIO_DT_SPEC_GET(LED1_NODE, gpios),
    GPIO_DT_SPEC_GET(LED2_NODE, gpios),
    GPIO_DT_SPEC_GET(LED3_NODE, gpios),
    GPIO_DT_SPEC_GET(LED4_NODE, gpios),
};

void main(void)
{
    for (int i = 0; i < ARRAY_SIZE(leds); i++) {
        if (!device_is_ready(leds[i].port)) {
            return;
        }
        gpio_pin_configure_dt(&leds[i], GPIO_OUTPUT_ACTIVE);
    }

    while (1) {
        for (int i = 0; i < ARRAY_SIZE(leds); i++) {
            gpio_pin_set_dt(&leds[i], 1);
            k_sleep(K_MSEC(200));
            gpio_pin_set_dt(&leds[i], 0);
        }

        for (int i = ARRAY_SIZE(leds) - 1; i >= 0; i--) {
            gpio_pin_set_dt(&leds[i], 1);
            k_sleep(K_MSEC(200));
            gpio_pin_set_dt(&leds[i], 0);
        }

        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < ARRAY_SIZE(leds); j++) {
                gpio_pin_set_dt(&leds[j], 1);
            }
            k_sleep(K_MSEC(250));
            for (int j = 0; j < ARRAY_SIZE(leds); j++) {
                gpio_pin_set_dt(&leds[j], 0);
            }
            k_sleep(K_MSEC(250));
        }
    }
}
```

---

## Key Learnings

- **DeviceTree overlays** must be placed under `boards/` with a filename matching the Zephyr board name (e.g., `rpi_pico.overlay`).
    
- **GPIO abstraction** via `gpio_dt_spec` structures simplifies code portability.
    
- **Hardware pin assignments** are separated from application logic for easy hardware swapping (e.g., porting to ESP32 or STM32).
    
- **Minimal Zephyr project structure** ensures easy scaling later (e.g., drivers, RTOS threads).
    