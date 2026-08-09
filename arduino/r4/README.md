# Arduino UNO R4 WiFi — working notes

Two boards, eBay rescues, <$10 total. Previous owners trashed the ESP32-S3
"system stuff"; both are now confirmed fully working — sketch upload over
USB, WiFi association, and HTTP round-trips (verified 2026-08-09 against
google generate_204).

## Build + upload (arduino-cli)

```bash
arduino-cli core install arduino:renesas_uno        # one-time
arduino-cli compile -b arduino:renesas_uno:unor4wifi <sketch_dir>
arduino-cli board list                              # find /dev/cu.usbmodem*
arduino-cli upload  -b arduino:renesas_uno:unor4wifi -p /dev/cu.usbmodemXXXX <sketch_dir>
```

Serial monitor: `arduino-cli monitor -p /dev/cu.usbmodemXXXX --config baudrate=115200`

## THE TRAIL — troubleshooting, in order

1. **Powered + running a sketch but not enumerating on USB → it's the
   CABLE.** Charge-only USB cables perfectly mimic a dead board (matrix
   lit, zero USB). This burned us twice. Swap for a known data cable
   before anything else.
2. WiFi facts: ESP32-S3 radio is **2.4GHz only**; SSID match is exact and
   case-sensitive.
3. On the R4 WiFi, USB + WiFi both live on the ESP32-S3 bridge. If the
   bridge firmware is genuinely trashed: reflash with Arduino's
   `uno-r4-wifi-usb-bridge` firmware (esptool via the ESP32 boot pads).
4. **RA4M1-direct fallback (real bricks):** mainline OpenOCD (≤0.12) has NO
   RA4M1 flash support — gdb-load through it cannot work. Use pyOCD over a
   PicoProbe/CMSIS-DAP on the SWD pads:

   ```bash
   pipx install pyocd
   pyocd pack install r7fa4m1ab
   arduino-cli compile -e -b arduino:renesas_uno:unor4wifi <sketch>   # -e exports .hex
   pyocd flash -t r7fa4m1ab <sketch>/build/arduino.renesas_uno.unor4wifi/<sketch>.ino.hex
   ```

## LED matrix (12x8, monochrome)

Frame = 3 x uint32, row-major, bit `(y*12+x)` counted from the MSB of
`frame[0]`. See `rapid_blink/` here, or the current working sketches in
`project_pixel_box/hardware/` (frowny + WiFi-activity indicator at pixel
(0,0): off = no WiFi, solid = associated, double-blink = HTTP exchange).
