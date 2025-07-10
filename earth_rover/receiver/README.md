# ESP-NOW Receiver

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
idf.py -p /dev/cu.usbmodem1442101 flash monitor
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
