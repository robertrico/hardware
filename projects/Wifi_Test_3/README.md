# Raspberry Pi Pico W + OLED: Quick Start Refresher

This is your refresher doc for jumping back into your Pico W + OLED + MicroPython project.

---

## 🧠 Project Overview
- Uses MicroPython on a Raspberry Pi Pico W
- Connects to Wi-Fi using `secrets.py`
- Fetches JSON from http://httpbin.org/json
- Displays `slideshow.author` field on an SSD1306 OLED

---

## 📁 Project Directory Layout
```
project-folder/
├── boot.py           # Optional 3-second delay on boot (for REPL access)
├── main.py           # Contains OLED + Wi-Fi + HTTP logic
├── secrets.py        # Stores your Wi-Fi credentials (NOT in git)
├── urequests.py      # Optional HTTP helper (not used if using socket)
└── ssd1306.py        # OLED driver (if not using a built-in one)
```

---

## 🧼 First-Time Setup (Already Done)
- MicroPython UF2 is already on the board — you don't need BOOTSEL anymore
- Pico will boot into MicroPython automatically when plugged in

---

## 🔁 Uploading Files to the Pico W
Use `mpremote`:

```bash
mpremote connect auto fs cp main.py :
mpremote connect auto fs cp secrets.py :
```

Upload any new file the same way.

You can soft-reset the board afterward:
```bash
mpremote connect auto exec "import machine; machine.reset()"
```

---

## 💻 REPL (Read-Eval-Print Loop)
Access the MicroPython REPL:
```bash
mpremote connect auto repl
```

### ⚠️ Note:
You may not see the `>>>` prompt right away. **Just hit Enter once**, and the prompt should appear.

---

## ▶️ Running Your Code
Once in REPL:
```python
import main
main.start()              # Connect to Wi-Fi and init OLED
main.display_json_author()  # Fetch and display author field
```

---

## 🛠️ Optional Dev Tip: Use `boot.py`
If you want a startup delay for easier REPL access, include this `boot.py`:
```python
import time
time.sleep(3)
```

---

## 🔌 Hardware Summary
- OLED connected to I2C1 (SDA=GP2, SCL=GP3)
- Pull-up resistors (internal or external)
- RUN pin connected to GND via button = hardware reset

---

Take a break, solder away, and come back ready to ship magic. 🛠️💡

