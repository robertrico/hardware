# Raspberry Pi Pico W - Networked GET Request Example

This project demonstrates making a simple TCP-based HTTP GET request using a Raspberry Pi Pico W with the Pico SDK and lwIP stack. The setup includes Wi-Fi connectivity, DNS resolution, and TCP request handling.

## Project Setup

### Requirements

- Raspberry Pi Pico W
- Pico SDK
- lwIP networking stack

### Building the Project

Set your Wi-Fi credentials via environment variables before building:

```bash
export WIFI_SSID="YourSSID"
export WIFI_PASSWORD="YourPassword"
```

Then, build with:

```bash
mkdir build
cd build
cmake ..
make
```

### Flashing and Debugging

The following commands were used successfully for debugging:

**Terminal 1:**

```bash
openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg -c "adapter speed 1000"
```

**Terminal 2:**

```bash
arm-none-eabi-gdb Wifi_Test_4.elf
```

Inside GDB:

```gdb
target remote localhost:3333
load
monitor reset init
continue
```

**Serial Output (for debug logging):**

```bash
screen /dev/tty.usbmodem1202 115200
```

### Troubleshooting Tips & Weirdness Encountered

- **CYW43 Wi-Fi Initialization Freeze:** Occasionally, the Pico W would freeze during Wi-Fi initialization, especially after software resets. The only reliable fix was to perform a hardware reset (unplug and re-plug the Pico). Attempts to fix this via software (`cyw43_arch_deinit`) caused further issues.

- **OpenOCD Connection Issues:** If the debugger pins (SWCLK and SWDIO) were reversed, OpenOCD wouldn't start properly. Ensure the correct wiring:

  ```
  Debugger Pico GP2 (SWCLK) → Target Pico SWCLK (Pin 24)
  Debugger Pico GP3 (SWDIO) → Target Pico SWDIO (Pin 25)
  Debugger GND → Target Pico GND
  ```

- **DNS Resolution Behavior:** DNS resolution with `dns_gethostbyname()` sometimes required waiting explicitly for the DNS callback. Immediate resolution wasn't always reliable. Thus, polling via `cyw43_arch_poll()` is essential for callbacks.

### Project Structure

- `main.c`: Core project file containing Wi-Fi setup, DNS, and GET request handling.
- `CMakeLists.txt`: Build configuration for Pico SDK.
- `lwipopts.h`: lwIP options tailored to enable TCP, UDP, DNS, and DHCP functionalities.

## Next Steps

Future work includes integrating JSON parsing (e.g., using `jsmn` or `cJSON`) for response handling and expanding error-handling robustness.

