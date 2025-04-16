# PicoBook – Pico W Internet Note Display

A minimalist embedded device that fetches and displays messages from a web server onto a small OLED screen. Designed for instant-on behavior with local Wi-Fi support, manual refresh, and optional hardware reset. Shaped and built like a small book, it combines physical presence with purposeful microcontroller design.

---

## What This Is
A Raspberry Pi Pico W-based tangible display device that:

- Boots and connects to Wi-Fi on power-up
- Fetches a note from a remote server (JSON over HTTP)
- Displays the message on a 128x64 SSD1306 OLED screen
- Supports a physical button press to fetch a new message
- Supports optional hardware reset via the Pico’s RUN pin
- Enclosed in a hand-cut, book-shaped plastic casing

---

## Hardware Used

| Component           | Description                              |
|---------------------|------------------------------------------|
| Raspberry Pi Pico W | Wi-Fi enabled microcontroller             |
| SSD1306 OLED        | 128x64 pixel I2C display (3.3V logic)     |
| Button 1            | GP16 (or GP0) used for manual fetch       |
| Button 2 (optional) | RUN → GND hardware reset switch           |
| Jumper Wires        | Standard male-to-male                    |
| Hand-built case     | Scored plastic sheet, folded and glued    |

---

## Wiring Summary

### OLED (I2C1)
- SDA → GP2 (Physical pin 4)
- SCL → GP3 (Physical pin 5)
- VCC → 3.3V
- GND → GND

### Button (Fetch New Message)
- One side → GP16 (or GP0)
- Other side → GND

### Optional Reset Button
- One side → RUN
- Other side → GND

> Tip: On breadboards, buttons must straddle the center trench to function correctly.

---

## Software

- Language: MicroPython (latest Pico W firmware)
- Display: `ssd1306.py` driver
- Networking: raw sockets (`urequests` not used)
- Server format:

```json
{ "note": "Hello from the internet!" }
```

Example local PHP server:
```bash
php -S 0.0.0.0:8081
```

Example `index.php`:
```php
<?php
header('Content-Type: application/json');
$notes = ["You're awesome!", "Stay hydrated.", "Keep building."];
echo json_encode(["note" => $notes[array_rand($notes)]]);
```

---

## File Layout
```
project-folder/
├── boot.py         # Optional REPL delay on startup
├── main.py         # All device logic (Wi-Fi, fetch, render)
├── secrets.py      # Wi-Fi credentials (never committed)
├── ssd1306.py      # OLED display driver
```

### `secrets.py` Format
```python
WIFI_SSID = "your-ssid"
WIFI_PASSWORD = "your-password"
```

---

## Deployment

### Upload Files
```bash
mpremote connect auto fs cp boot.py :
mpremote connect auto fs cp main.py :
mpremote connect auto fs cp secrets.py :
mpremote connect auto fs cp ssd1306.py :
```

### Reboot Device
```bash
mpremote connect auto exec "import machine; machine.reset()"
```

### Connect to REPL
```bash
mpremote connect auto
```

---

## Behavior Summary

| Action              | Result                                      |
|---------------------|---------------------------------------------|
| Plug in power       | Connects to Wi-Fi, fetches and displays note |
| Press fetch button  | Fetches and replaces message                |
| Press reset button  | Full hardware reboot                        |

---

## Project Learnings

- Raw socket usage in MicroPython (no TLS, no external libs)
- OLED line-wrapping and text centering for 128x64 layout
- Secrets handling via `git-secrets` and strict `.gitignore`
- REPL lockout prevention using `boot.py` delay
- Hands-on practice with desoldering headers and trimming fitment for enclosures

---

## Known Issues

- If your server fails or hangs, the device may soft-lock or show blank
- Some OLEDs (SSD1309) require driver mods; this uses SSD1306-compatible modules
- Does not retry failed Wi-Fi connects after boot; must reset

---

## Status
- Wi-Fi connects and screen displays notes
- Server became unresponsive during extended test (not firmware fault)
- Production case is hand crafted and prone to breakage.

---

## Final Words

This was a fun project. I do not plan on furthering anymore MicroPython unless I deem it necessary. Baremetal is the way to go for my understanding of MCUs and how they communicate with things. I found MicroPython EXCELLENT to quickly prototype ideas, but C++ to fine-tune the code. ( Not that my code is polished. )
