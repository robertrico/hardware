# PicoBook

PicoBook is a compact, self-contained embedded device that fetches book titles and authors over Wi-Fi and displays them on an OLED screen. The device is shaped like a small book and serves as both a practical message board and a demonstration of embedded capabilities.

---

## 🧠 Features

- Wi-Fi connection to a PHP-based endpoint (EC2-hosted)
- JSON parsing with line-wrapped, centered OLED rendering
- GPIO button to fetch new messages on demand
- Scored, cut, and folded plastic enclosure
- Powered via USB or buck converter
- Fully hand-assembled and soldered

---

## 💡 Technologies Used

- Raspberry Pi Pico W
- MicroPython
- I2C (OLED communication)
- GPIO (button handling)
- Hot glue + hand tools (enclosure)
- Hobby Plastic, Plastic Cement and X-acto Knife
- `git-secrets` and `.gitignore` for safety

---

## 🖼️ Gallery

![Front view](https://raw.githubusercontent.com/robertrico/hardware/main/projects/PicoBook/images/front.jpeg)
![Open view](https://raw.githubusercontent.com/robertrico/hardware/main/projects/PicoBook/images/inside.jpeg)

---

## 🔗 Source Code & Circuit

- [Main Code](https://github.com/robertrico/hardware/blob/main/projects/PicoBook/main.py)
- [Wiring Diagram](https://github.com/robertrico/hardware/tree/main/projects/PicoBook/docs/wiring_diagram.md)
- [Case Design](https://github.com/robertrico/hardware/tree/main/projects/PicoBook/docs/case-design.jpeg)

---

## 📎 Skills Demonstrated

- Embedded circuit assembly and I2C debugging
- OLED text rendering with MicroPython
- Handling `mpremote`, firmware recovery, and lockups
- Secrets prevention in version control
- Working with and customizing GitHub Pages

---

## 🔜 Future Improvements

- Add power switch or latch closure
- Optional soft reset via GPIO
- Replace headers with low-profile solder joints
- Modular power regulation circuit for battery input

[View Code](/tree/main/projects/PicoBook/code)

