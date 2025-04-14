# Toolchains and Build Notes

This document captures working toolchains, environment notes, and setup quirks encountered during embedded systems development across projects.

---

## 🛠️ Current Working Toolchain (as of April 2025)

### MicroPython (Pico W)
- Firmware: `rp2-pico-w-20230426.uf2`
- Editor: VS Code w/ `mpremote`
- Board: Raspberry Pi Pico W
- Upload: `mpremote connect auto fs cp main.py :`

### C/C++ (Pico SDK)
- OS: macOS (Apple Silicon, M3)
- Compiler: `arm-none-eabi-gcc (brew)`
- SDK: Raspberry Pi Pico SDK (latest, cloned manually)
- Build System: CMake
- Notes:
  - Must explicitly set toolchain file on M1/M2/M3 macs
  - `lwipopts.h` must be present when using Wi-Fi

### ESP-IDF (ESP32)
- Platform: ESP32-C3 Dev Board (future use)
- Install via `idf.py install`
- Use `idf.py build flash monitor`


---

## 🧠 Notes and Gotchas

### `mpremote` Issues
- Can fail if code runs infinite loop (use BOOTSEL to recover)
- `TransportError: could not enter raw repl` usually means the script auto-ran on boot

### Secrets Prevention
- Use `git-secrets` to prevent accidental pushes of:
  - `wifi_password`, `secrets.py`, `.env`
- Add rules: `git secrets --add 'wifi_password\s*=\s*".+"'`

### Wi-Fi Debugging
- Always check if firmware flashed is Pico **W**, not regular Pico
- Use `network.WLAN().isconnected()` to confirm

### OLED I2C (SSD1306 / SSD1309)
- Libraries used: `ssd1306.py`, sometimes `pico-ssd1306` for C
- I2C Pins are flexible (RP2040 is fully muxed)

---

## 📎 Next Up
- Add toolchain setup for bare-metal RP2040 (no Pico board)
- Log `idf.py` quirks once ESP work begins
- Potential STM32CubeMX integration notes (future)

