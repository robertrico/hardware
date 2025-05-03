# 

## Objective

Create a minimal FreeRTOS application that blinks an LED at regular intervals on the following boards:

- Raspberry Pi Pico W (RP2040)
    
- Raspberry Pi Pico W2 (RP2040, enhanced)
    
- ESP32 (Xtensa LX6 MCU)
    

This project demonstrates setting up FreeRTOS tasks, initializing GPIOs, and scheduling tasks on a FreeRTOS-enabled microcontroller.

---

## Hardware Requirements

- Raspberry Pi Pico W, Pico W2, or ESP32 Dev Board
    
- USB Cable for flashing and serial communication
    
- 1x LED (optional if using onboard LED)
    
- 1x Resistor (220 Ohm if using external LED)
    
- Breadboard and jumper wires (if external wiring)
    

## Software Requirements

- CMake (3.13 or higher)
    
- GNU Arm Embedded Toolchain (for RP2040)
    
- ESP-IDF (for ESP32, if targeting ESP32)
    
- FreeRTOS Kernel Source
    
- OpenOCD / ESPTool / Picotool (depending on board)
    

## Directory Structure

```bash
freertos-blinky/
├── CMakeLists.txt
├── FreeRTOSConfig.h
├── main.c
├── config/
│   ├── pico_w.h
│   ├── pico_w2.h
│   └── esp32.h
└── README.md
```

## main.c Example Code

```c
#include "FreeRTOS.h"
#include "task.h"

// Include board-specific GPIO headers
#ifdef CONFIG_BOARD_PICO_W
#include "pico/stdlib.h"
#define LED_PIN 25
#elif defined(CONFIG_BOARD_PICO_W2)
#include "pico/stdlib.h"
#define LED_PIN 25
#elif defined(CONFIG_BOARD_ESP32)
#include "driver/gpio.h"
#define LED_PIN GPIO_NUM_2
#endif

void led_task(void *pvParameters) {
    while (1) {
#ifdef CONFIG_BOARD_ESP32
        gpio_set_level(LED_PIN, 1);
#else
        gpio_put(LED_PIN, 1);
#endif
        vTaskDelay(pdMS_TO_TICKS(500));

#ifdef CONFIG_BOARD_ESP32
        gpio_set_level(LED_PIN, 0);
#else
        gpio_put(LED_PIN, 0);
#endif
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

int main() {
#ifdef CONFIG_BOARD_ESP32
    gpio_pad_select_gpio(LED_PIN);
    gpio_set_direction(LED_PIN, GPIO_MODE_OUTPUT);
#else
    stdio_init_all();
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);
#endif

    xTaskCreate(led_task, "LED Task", 256, NULL, 1, NULL);
    vTaskStartScheduler();

    while (1) {}
}
```

## Build and Flash Instructions

### Pico W / Pico W2

1. Clone Pico SDK and prepare FreeRTOS (optional integration).
    
2. Configure CMake project:
    

```bash
mkdir build && cd build
cmake -DPICO_BOARD=pico_w ..
make -j$(nproc)
```

3. Flash:
    

```bash
picotool load -f your_project.uf2
```

### ESP32

1. Set up ESP-IDF and FreeRTOS components.
    
2. Configure and build:
    

```bash
idf.py set-target esp32
idf.py build
```

3. Flash:
    

```bash
idf.py -p (PORT) flash
```

## Key FreeRTOS Concepts Demonstrated

- Task Creation: `xTaskCreate()`
    
- Task Scheduling: `vTaskStartScheduler()`
    
- Software Delay: `vTaskDelay()`
    
- GPIO Control on Bare Metal
    

## Notes

- Stack size for tasks can be tuned based on MCU constraints.
    
- For production, watchdog timers and task health monitoring should be added.
    
- RTOS tick rate configuration is adjustable in `FreeRTOSConfig.h`.
    
- Additional peripherals (I2C, SPI, UART) can be added into separate tasks.
    

## Future Improvements

- Add multiple tasks with varying priorities
    
- Implement a simple CLI over UART
    
- Use FreeRTOS timers instead of task-based blinking
    
- Add OTA update capability (Wi-Fi based for ESP32)
    

---

## References

- [FreeRTOS Official Documentation](https://freertos.org/)
    
- [Pico SDK Documentation](https://datasheets.raspberrypi.com/pico/raspberry-pi-pico-c-sdk.pdf)
    
- [ESP-IDF Programming Guide](https://docs.espressif.com/projects/esp-idf/en/latest/)
    

---

**End of Project Readme**