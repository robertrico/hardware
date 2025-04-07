# Pico W Internet Note Display

A minimalist microcontroller device that fetches a message from a web server and displays it on a small OLED screen. Designed to boot on power, connect to Wi-Fi, and support a manual fetch button and hardware reset.

---

## What This Is
A Raspberry Pi Pico W-based device that:

- Connects to Wi-Fi on power-up
- Fetches a note from a web server
- Displays the note on an SSD1306 OLED screen
- Supports a manual button press to refetch the note
- Supports a hardware reset via the RUN pin

---

## Hardware Used

| Component         | Description                             |
|------------------|-----------------------------------------|
| Raspberry Pi Pico W | Microcontroller with Wi-Fi               |
| SSD1306 OLED      | 128x64 pixel I2C display (3V3 logic)     |
| Button 1          | Connected to GP16 for note refetch      |
| Button 2 (optional) | Connected between RUN and GND for reset |
| Jumper Wires      | Standard male-to-male                   |
| Breadboard        | Optional, for quick prototyping         |

---

## Wiring Summary

### OLED (I2C1)
- SDA → GP2 (Physical pin 4)
- SCL → GP3 (Physical pin 5)
- VCC → 3V3
- GND → GND

### Button (Refetch Note)
- One side → GP16 (Physical pin 21)
- Other side → GND

### Optional Reset Button
- One side → RUN pin
- Other side → GND

> Buttons must straddle the center trench on a breadboard for correct contact.

---

## Software

- Language: MicroPython
- Display Driver: `ssd1306.py`
- Networking: Raw sockets (no external libraries needed)
- Server: Any HTTP server returning `application/json` in the format:

```json
{ "note": "Hello from the internet!" }
```

Example PHP server:
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
├── main.py         # Contains all logic (OLED, Wi-Fi, HTTP, button)
├── secrets.py      # Stores Wi-Fi credentials (not committed)
├── ssd1306.py      # OLED driver (if not built-in)
└── boot.py         # Optional 3s delay for REPL access
```

### `secrets.py` example:
```python
WIFI_SSID = "your-ssid"
WIFI_PASSWORD = "your-password"
```

---

## Usage

### Upload the Files
```bash
mpremote connect auto fs cp main.py :
mpremote connect auto fs cp secrets.py :
mpremote connect auto fs cp ssd1306.py :
```

### Reboot the Pico
```bash
mpremote connect auto exec "import machine; machine.reset()"
```

### Device Behavior
- On power-up, it fetches and displays the note
- Press the button to re-fetch anytime
- Reset with the RUN button if needed

---

## Behavior Summary

| Action                | Result                        |
|-----------------------|-------------------------------|
| Plug into USB power   | Boots, connects to Wi-Fi, fetches message |
| Press fetch button    | Re-fetches and displays new message |
| Press reset button    | Fully reboots device |

---

## Notes
- Minimal external dependencies; built entirely with MicroPython socket and display modules
- Compatible with any HTTP server that returns a valid JSON note object
- Designed for continuous power-on environments
- Reset functionality ensures reliability for long-running use cases

---

Clean hardware. Minimal firmware. Purpose-built for demo and diagnostic displays.

