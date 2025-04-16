# XIAO ESP32-C3 Digital Button → LED Project

This project demonstrates a verified digital input/output system using the Seeed Studio XIAO ESP32-C3. A button press on one pin controls an LED on another, based on tested GPIO behavior and confirmed pin mappings.

---

## ✅ Objective

- Push a button on D2 (GPIO4)
- Toggle an LED connected to D9 (GPIO9)

---

## 📦 Hardware

- Seeed Studio XIAO ESP32-C3
- Pushbutton
- LED (any color)
- 330Ω resistor
- Breadboard and jumper wires

---

## 📄 Wiring

- **D1 → GPIO3** → button input
  - One side of button to D1 (GPIO3)
  - Other side to GND
- **D9 → GPIO20** → LED output
  - GPIO20 to LED anode
  - LED cathode to 330Ω resistor → GND

---

## 🔧 Build Setup

1. **Clone ESP-IDF** into your home folder:

```bash
cd ~
git clone --recursive https://github.com/espressif/esp-idf.git
cd esp-idf
./install.sh esp32c3
```

2. **Export environment before building:**

```bash
source ~/esp-idf/export.sh
```

3. **Build and flash:**

```bash
idf.py set-target esp32c3
idf.py build
idf.py -p /dev/tty.usbmodemXXXX flash monitor
```

---

## ✅ Verified GPIO Map

Based on this [official pinout](https://files.seeedstudio.com/wiki/XIAO_WiFi/pin_map-2.png) and full board validation:

| Silkscreen | GPIO\_NUM | Status | Notes                     |
| ---------- | --------- | ------ | ------------------------- |
| D0         | GPIO2     | ✅      |                           |
| D1         | GPIO3     | ✅      | Used for button input     |
| D2         | GPIO4     | ✅      |                           |
| D3         | GPIO5     | ✅      |                           |
| D4         | GPIO6     | ✅      | Was dim, works post-setup |
| D5         | GPIO7     | ✅      |                           |
| D6         | GPIO21    | ✅      | Verified digital output   |
| D7         | GPIO20    | ✅      | Verified digital output   |
| D8         | GPIO8     | ✅      |                           |
| D9         | GPIO9     | ✅      | LED output used here      |
| D10        | GPIO10    | ✅      |                           |

All pins, including ADC2-bound ones (e.g., GPIO5), were confirmed working in digital mode.

---

## 💡 Behavior

- Internal pull-up used on input pin
- Button reads HIGH when open, LOW when pressed
- LED turns ON only when button is actively pressed

---

## 🧠 Lessons Learned

- Strapping pins like GPIO0 and GPIO2 can interfere with boot or drive behavior
- GPIO mappings must come from board-level docs, not silicon-only definitions
- Even factory-fresh boards can show ghost behavior on misconfigured pins
- Testing each GPIO in isolation ensures high confidence in hardware

---

## 📌 Summary

This project forms the foundation for an ESP-NOW-based remote LED control system. All I/O pins used were validated for both logic level swing and electrical output behavior using a multimeter and live LED tests.

You're now cleared for Phase 2: radio communication.

