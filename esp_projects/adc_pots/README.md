# 🛠️ ESP32-C3 ADC + GPIO LED Control with Seeed XIAO

This project demonstrates using the ADC (Analog-to-Digital Converter) on a Seeed XIAO ESP32-C3 board to read a potentiometer and control an LED.

---

## 📌 Summary

* A potentiometer is connected to an ADC-capable pin.
* The ADC value is read using the ESP-IDF ADC Oneshot driver.
* Based on the voltage level (determined by the pot), an LED connected to a digital GPIO is toggled.

---

## 🧠 Learnings

1. **GPIO Mapping Is Non-Trivial on XIAO**

   * Not all GPIOs are exposed on headers.
   * Refer to the official [Seeed XIAO ESP32-C3 Getting Started Guide](https://wiki.seeedstudio.com/XIAO_ESP32C3_Getting_Started/) and [ESP32-C3 datasheet](https://www.espressif.com/sites/default/files/documentation/esp32-c3_datasheet_en.pdf).
   * GPIO0 is a solder-only pad and is also a BOOT pin — avoid for inputs unless absolutely necessary.

2. **ADC Channels Must Match GPIOs**

   * Channel 4 = GPIO4 ( But is 3rd physically. Pay attention to names).
   * All other ADC channels work as expected.

3. **Use ADC Oneshot Driver (esp\_adc/adc\_oneshot.h)**

   * Works well and avoids legacy deprecation issues.
   * Configure bit width and attenuation properly.

4. **Pull Resistors Matter**

   * Ensure external circuits (like a potentiometer) are not affected by internal pull-ups or pull-downs.
   * Explicitly disable pull-up and enable pull-down if needed.

5. **Watch ADC Resolution**

   * 12-bit resolution = values range from 0 to 4095 (0V to 3.3V).

6. **Test Potentiometer Physically**

   * Connect LED directly to pot temporarily to verify analog functionality before debugging ADC.

---

## ⚙️ Setup

```bash
# 1. Export updated CMake path ( IF CMAKE COMPLAINS ONLY )
# export PATH="/usr/local/Cellar/cmake/4.0.1/bin:$PATH"

# 2. Export ESP-IDF environment
source ~/esp/esp-idf/export.sh

# 3. Set build target
idf.py set-target esp32c3

# 4. Build
idf.py build

# 5. Flash and monitor
idf.py -p /dev/cu.usbmodemXXXX flash monitor
```

---

## 🔋 Hardware Used

* **Seeed XIAO ESP32-C3**
* **Potentiometer** (\~5k Ohm)
* **LED** (connected via resistor to GND)

**Connections:**

* Pot VCC ➝ 3.3V
* Pot GND ➝ GND
* Pot Wiper ➝ GPIO0 (ADC\_CHANNEL\_4)
* LED Anode ➝ GPIO21 (D2 via resistor)
* LED Cathode ➝ GND

---

## 💡 Logic

```c
if (adc_val < 700 || adc_val > 3000)
    turn LED on;
else
    turn LED off;
```

---

This setup is a perfect introduction to reading analog signals and performing simple GPIO logic in ESP-IDF without Arduino.

Bare metal. CMake. Precision.

---
