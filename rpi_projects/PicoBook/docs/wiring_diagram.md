# Wiring Diagram - PicoBook

This document outlines the wiring connections for the PicoBook project. The device consists of a Raspberry Pi Pico W, an SSD1309 OLED display, and a push-button. All components are connected via a soldered or breadboard-based setup.

---

## 📦 Components

- **Raspberry Pi Pico W**
- **SSD1309 128x64 OLED Display (I2C)**
- **Tactile Push Button**
- **10kΩ Resistor (pull-up)**
- **Jumper Wires / Hookup Wire**

---

## 🧠 Pin Mapping

| Component       | Function      | Pico GPIO | Notes                  |
|----------------|---------------|-----------|------------------------|
| OLED Display   | SDA (I2C)     | GPIO 2    | I2C1 SDA               |
| OLED Display   | SCL (I2C)     | GPIO 3    | I2C1 SCL               |
| OLED Display   | VCC           | 3.3V      | Use regulated output   |
| OLED Display   | GND           | GND       |                        |
| Button         | Signal        | GPIO 16   | Internal pull-up used  |
| Button         | GND           | GND       | One side to ground     |

---

## ⚠️ Wiring Notes

- OLED uses **I2C1**, which is set in code using GPIO 2 (SDA) and GPIO 3 (SCL).
- Button is connected to **GPIO 16** and uses **internal pull-up**.
- Be sure to debounce the button in code or via capacitor if needed.
- Power is provided via USB or buck converter regulated to 3.3V.

---

## 🔧 Optional Additions

- Add 0.1µF decoupling capacitor across OLED VCC/GND
- Add reset button tied to the Pico's `RUN` pin
- For production: use low-profile headerless solder joints

---

## 🖼️ Visual Diagram

*(Insert hand-drawn or digital wiring diagram here once created. Recommend Fritzing or KiCad export.)*

---

## 📎 Related Files

- [Main Code](https://github.com/robertrico/hardware/blob/main/projects/picobook/code/main.py)
- [Picobook Overview](picobook.md)
- [Project Gallery](https://github.com/robertrico/hardware/tree/main/projects/picobook/images)