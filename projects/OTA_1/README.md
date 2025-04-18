# OTA Phase 2 - Dual Partition Firmware Update System for Pico W

## Overview
This project implements a minimal OTA (Over-the-Air) update system for the Raspberry Pi Pico W using a dual-partition (A/B) firmware model. The current firmware is capable of:

- Connecting to Wi-Fi using environment-defined credentials
- Checking a remote server for a newer firmware version
- Downloading a raw `.bin` firmware image if a newer version exists
- Writing the image to a predefined alternate flash partition (OTA Slot B)

The boot switching logic is still under development, but the core pipeline for receiving and writing firmware is complete.

This project is designed for embedded developers who want to understand and build a boot-safe OTA system for microcontrollers with no operating system.

---

## Hardware
- Raspberry Pi Pico W
- External server (tested with macOS) hosting OTA metadata and firmware images
- LEDs (optional) for status indicators on GPIO 14 (green), 15 (red), 16 (yellow)

---

## Folder Structure
```
.
├── main.cpp                // Entry point and control flow
├── ota_manager.cpp/.hpp    // HTTP GET, metadata parsing, flash writing
├── wifi_manager.cpp/.hpp   // Wi-Fi init and connection testing
├── version.h               // Defines the current firmware version
├── CMakeLists.txt          // Pico SDK build configuration
```

---

## Firmware Layout (Flash Memory Map)
```
0x000000  Bootloader (UF2 default)
0x001000  Firmware A (default)
0x0C0000  Firmware B (OTA slot)
0x140000  Config region (boot flags, metadata)
```

All OTA writes occur at offset `0x0C0000`. Future work will use `0x140000` to write version flags or boot state to enable automatic switching.

---

## Metadata Format (`meta.json`)
```
{
  "version": "1.01"
}
```
This file must be hosted at the path defined in `OTA_META_PATH` in `ota_manager.cpp`.

The actual firmware file will be generated as:
```
/ota/firmware_<version>.bin
```
Example: `firmware_1_01.bin`

The current implementation constructs the URL internally using a template string.

---

## How It Works
1. **Startup**: Wi-Fi is initialized and connection is attempted.
2. **Connectivity Check**: A test GET request confirms internet access.
3. **Update Check**: `meta.json` is fetched and parsed for version info.
4. **Version Compare**: If the remote version differs from the `#define VERSION` in `version.h`, a download is triggered.
5. **Download and Write**:
   - The `.bin` file is downloaded
   - Each chunk is written to OTA B region at `0x0C0000`
   - Flash erasure and programming are performed safely in aligned blocks
6. **Final Step** (WIP): A boot flag will be written to indicate that the bootloader or firmware should jump to Firmware B.

---

## Requirements
- [Pico SDK](https://github.com/raspberrypi/pico-sdk)
- CMake 3.13+
- A working HTTP server (local or remote) to serve OTA files

---

## Known Limitations
- There is no current boot-switching logic. Firmware B is written, but never executed.
- No TLS/SSL support is implemented.
- The HTTP parsing is manual and limited to simple JSON key extraction.
- There is no checksum validation or rollback logic yet.

---

## Next Steps
- Implement version-aware boot decision (Phase 3)
- Add CRC or checksum validation of downloaded firmware
- Add rollback flag and failure recovery behavior
- Consider moving to a bootloader-aware partition map