# ESP-NOW Button-to-LED Trigger

This project uses two ESP32-C3 devices to demonstrate simple ESP-NOW communication:
- A **transmitter** device sends a `"LIGHT_ON"` message when a button is pressed.
- A **receiver** device reads that message and momentarily toggles an LED.

This serves as a minimal point-to-point wireless control proof of concept before evolving into a more robust RF controller system.

---

## 🧰 Requirements

- Two ESP32-C3 boards
- GPIO wiring:
  - **Transmitter**: Button to GPIO3 (D1)
  - **Receiver**: LED to GPIO20 (D7)
- `esp-idf` v5.5 (or compatible)
- CMake 4.0.1+

---

## ⚙️ Setup

```bash
# 1. Export updated CMake path
export PATH="/usr/local/Cellar/cmake/4.0.1/bin:$PATH"

# 2. Export ESP-IDF environment
source ../../esp-idf/export.sh

# 3. Set build target
idf.py set-target esp32c3

# 4. Build
idf.py build

# 5. Flash and monitor
idf.py -p /dev/cu.usbmodemXXXX flash monitor
```

---

## 🛡️ MAC Address Mapping

When both devices are flashed, they’ll log their MAC addresses at boot:

```text
TX: My MAC: A0:85:E3:0C:A2:F4
RX: My MAC: A0:85:E3:0D:72:68
```

Update the TX `esp_now_peer_info_t` with the RX MAC (already done in this repo):

```cpp
memcpy(peerInfo.peer_addr, (uint8_t[]){0xA0, 0x85, 0xE3, 0x0D, 0x72, 0x68}, 6);
```

---

## 🔭 Logic

- TX monitors the button state and sends `"LIGHT_ON"` via `esp_now_send()` when pressed.
- RX compares incoming message string (safe-length parsed) to `"LIGHT_ON"`:
  - If it matches, it triggers GPIO20 HIGH for 120ms then LOW.
  - All other payloads are logged as unknown.

---

## 🔭 Next Steps

You're ready to:
1. Expand the controller with additional button mappings or UI.
2. Replace ESP-NOW with longer-range protocols (e.g. LoRa, RFM69, or ESP-NOW over mesh or relay).

