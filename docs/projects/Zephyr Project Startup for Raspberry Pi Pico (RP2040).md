## Objective

Build a minimal Zephyr application that successfully boots on the Raspberry Pi Pico (RP2040) and prints a "Hello World" message over the USB serial console.

---

## Environment Setup

### Host System

- macOS M3 Max
    
- Zephyr SDK 0.17.0 installed
    
- Zephyr Project cloned (`v4.1.99` branch used)
    
- Python 3.13 virtual environment created and activated
    
- west installed and initialized
    

### Board

- Raspberry Pi Pico (RP2040)
    
- Target board: `rpi_pico`
    

## Build and Flash Commands

```bash
# Set up environment (inside virtualenv)
source zephyr/zephyr-env.sh

# Build the Hello World sample for rpi_pico
west build -p always -b rpi_pico zephyr/samples/hello_world

# Flash the firmware
west flash
```

---

## Expected Output

After flashing, open a serial monitor on the USB CDC device:

```bash
screen /dev/tty.usbmodemXXXXX 115200
```

You should see:

```text
*** Booting Zephyr OS build v4.1.0-3126-gbef5abd29344 ***
Hello World! rpi_pico/rp2040
```

---

## Summary

- Zephyr toolchain and west build system set up successfully.
    
- Hello World project built for `rpi_pico`.
    
- Board boots into Zephyr OS.
    
- USB serial output verified.
    

---

## Next Steps

- Flash an external LED connected to a GPIO.
    
- Explore basic peripherals (UART, I2C, SPI).
    
- Set up Zephyr logging for debugging over USB.
    
- Prepare groundwork for future PicoW-specific Wi-Fi projects (after correct board support is configured).