### ⚡ Power & Supply Systems

**Custom Breadboard Power Supply Build** `[planned]`  
_Project Focus:_ Design and build a power supply tailored for breadboard use. Explore stepping down voltage using both off-the-shelf modules and discrete components. Optionally reuse salvaged wall warts and power supplies. Include switchable output levels (e.g., 3.3V, 5V) and overcurrent protection.

**RSR 705K Multimeter Test & Repair** `[planned]`  
_Project Focus:_ Test and restore an old RSR 705K multimeter. Power with a fresh 9V battery, inspect internal components, clean contacts, and diagnose any range or display faults.

**Vintage Multimeter Clone (Custom Kit)** `[proposed]`  
_Project Focus:_ Inspired by the RSR 705K, create a minimalist digital voltmeter circuit using op-amps or ADCs and a 7-segment or OLED display. Begin on a breadboard and consider designing a PCB later.

**Add Battery Supply to PicoBook** `[planned]`  
_Project Focus:_ Select and integrate a compact battery pack into the PicoBook project for portable operation. Power design must support future OTA and wireless use cases.

---

### 📡 Communication & RF Projects

**Custom ESP-NOW Controller Pair (Inspired by Propel X-Wing Project)** `[planned]`  
_Project Focus:_ After exploring the Propel X-Wing drone controller without successful signal decoding, we pivoted to creating our own communication system. Two ESP32-C3 modules now talk via ESP-NOW protocol, laying the groundwork for a fully custom controller-to-receiver setup to trigger events and actions wirelessly.

**Secure RF Lock System** `[planned]`  
_Project Focus:_ Design a highly secure RF-based lock system for your office using complex channel hopping, unique signal timing, and button-hold logic to prevent unauthorized access. Inspired by a discussion on the difficulty of intercepting proprietary RF signals (Propel controller context).

**Raspberry Pi to Arduino RF Bridge** `[planned]`  
_Project Focus:_ Build a communication bridge between a Raspberry Pi and Arduino Uno using RF modules. Use this to test and explore basic RF protocols, packet handling, and bidirectional messaging. Lay groundwork for distributed systems or sensor/actuator networks.

**Logic Analyzer Signal Generator** `[proposed]`  
_Project Focus:_ Create a pattern generator with Pico or ESP32 to emit test I2C/SPI/UART signals for use with a logic analyzer. Ensures clean test conditions for decoding practice.

**LoRa Rover Comm Stack** `[proposed]`  
_Project Focus:_ Develop a dedicated communication layer using LoRa for the long-range rover project. Focus on protocol structure, messaging reliability, and control interaction.

**Salvaged Wi-Fi Chip Interface (WM8192EU)** `[planned]`  
_Project Focus:_ Connect and communicate with a salvaged USB Wi-Fi module (WM8192EU). Determine if a custom driver is needed or if USB host communication is viable. Explore integration with ESP32-C3 and test potential for embedded wireless augmentation.

**DSC RF Module Extraction & Reuse** `[proposed]`  
_Project Focus:_ Desolder and identify the RF daughterboard from the DSC PG9904P motion detector. Determine protocol and potential reuse as a transmitter or receiver module in your own MCU projects.

---

### 🧠 Interface, Control & Automation

**AI-Controlled Input & IO (Jarvis-Style Assistant)** `[planned]`  
_Project Focus:_ Build a lab assistant system using OpenAI API as a natural language interface. Include voice control, multi-screen output redirection, and GPIO/serial command capability for connected devices.

**Pico UART Serial Terminal w/ RJ11 Interface** `[planned]`  
_Project Focus:_ Create a dedicated UART reader using a Pico or RP2040 with a full-color OLED display. Use RJ11 connectors for compact and standardized UART wiring. Include a breakout board with serial input mapped to two GPIO pins. Function as a standalone terminal for debugging or interfacing with serial-output devices.

**"Commit Button" Project** `[planned]`  
_Project Focus:_ Build a physical button that, when pressed, triggers a Git commit and push via Wi-Fi. Emphasize clean GPIO to cloud interaction, software integration, and input debouncing.

**Custom RP2040 Flash Jig** `[proposed]`  
_Project Focus:_ Design and fabricate a PCB for flashing RP2040 modules with clean connections and reset/run logic. Can double as a breakout board for testing MCU batches.

**OLED Screen Art Generator** `[proposed]`  
_Project Focus:_ Use a full-color OLED display to show animated art, sensor summaries, or system status. Can evolve into a general-purpose visualization tool for embedded projects.

**Design Custom RP2040 PCB for PicoBook** `[planned]`  
_Project Focus:_ Build a compact PCB with an RP2040 and enough GPIOs to support the PicoBook features. Include debug header and serial access. Primary goal is to recover and repurpose the existing internal PicoW.

**Learn PIO Assembly & Byte Movement** `[planned]`  
_Project Focus:_ Study the Raspberry Pi Pico's Programmable I/O (PIO) block. Write basic assembly programs that move, shift, and manipulate bytes using state machines. Build a mental model of parallel I/O orchestration.

**GPIO Partitioned Bootloader Firmware** `[proposed]`  
_Project Focus:_ Create firmware for the PicoW that acts as a bootloader, mapping each GPIO to its own firmware partition. Enable each pin to act as an entry point for independent logic, using jumper-based boot selection. Heavy emphasis on linker scripts, flash layout, memory mapping, and SDK internals.

**Track memcpy/memset Usage via __wrap Attributes** `[proposed]`  
_Project Focus:_ Use `__wrap_memcpy` and `__wrap_memset` to intercept calls on the PicoW. Count usage at runtime and analyze usage patterns. Goal: determine minimum required usage in a clean dummy firmware to better understand memory operations under the SDK.

---

### 🧪 Sensors, Instrumentation & Environment

**Over-the-Air (OTA) Firmware Upgrades** `[in progress]`  
_Project Focus:_ Build a device that can receive firmware updates remotely via Wi-Fi or Bluetooth. Implement integrity checks and a rollback mechanism.

**Power Consumption Management** `[planned]`  
_Project Focus:_ Design a battery-powered sensor node that uses sleep modes, dynamic clock scaling, and wake-on-interrupt to minimize power draw.

**Hot Tub Smart Water Quality Analyzer** `[planned]`  
_Project Focus:_ Build an automated device that samples hot tub water using pumps and tubes to measure pH, alkalinity, and temperature. Analyze results and determine whether adjustments are needed. Integrate with Wi-Fi or BLE to report status and log conditions over time.

**Sensor Calibration Suite** `[proposed]`  
_Project Focus:_ Build a standalone device to help calibrate common sensors (temperature, pH, light, motion) using known test values and serial output for reference.

**Basic Motor ESC Driver** `[proposed]`  
_Project Focus:_ Build a basic motor control driver using either discrete transistors or modules like TB6612FNG. Good foundation for motor speed, direction, and PWM-based control.

**Propulsion Stability Platform** `[proposed]`  
_Project Focus:_ Design a platform to test multi-axis analog or digital inputs for use in stabilization or motion control. Can simulate balancing platforms or camera/gimbal mounting.

**PIR Lens and Sensor Standalone Build** `[proposed]`  
_Project Focus:_ Desolder the PIR motion sensor from the DSC device and rebuild a basic motion detector circuit using GPIO and an OLED or LED indicator. Learn how the Fresnel lens shapes detection fields.

**Connect PicoBook to Local Server** `[planned]`  
_Project Focus:_ Establish local wireless communication between PicoBook and a server. Enables config updates, logging, and diagnostics. Prepares groundwork for OTA delivery and input routing.

**Implement OTA Updates to PicoBook** `[planned]`  
_Project Focus:_ Extend the OTA framework to allow firmware, config, and SSID/password updates on the PicoBook. Dependent on: local network connection, Wi-Fi credentials delivery, and power reliability.

**AI-Curated Smart Plant Keeper** `[proposed]`  
_Project Focus:_ Use edge AI (Ollama or similar) to monitor and care for a living plant with minimal prompting. Begin with sensing and messaging (soil moisture, light, temp), then extend to water/nutrient delivery, shade, and interaction systems. Serves as a proving ground for autonomous embedded AI behavior.

---

### 🔧 Reverse Engineering & Salvage

**Peripheral Interfaces** `[planned]`  
_Project Focus:_ Create a modular sensor hub that communicates with peripherals (I2C, SPI, UART). Include hot-swappable or runtime-detectable peripherals.

**Apple I Recreation** `[planned]`  
_Project Focus:_ Recreate Steve Wozniak’s original Apple I computer from schematics. Emphasize understanding of early microprocessors, memory design, clock generation, and minimalistic system design.

**Long-Range Rover with Modular Tools** `[planned]`  
_Project Focus:_ Build a rugged, slow-moving rover using salvaged parts and controlled via LoRa, Wi-Fi, or CLI. Incorporate sensors, motor drivers, tooling modules, and a task queue system for autonomous or semi-autonomous behavior.

**Mini Helicopter Drive Train Test Rig** `[planned]`  
_Project Focus:_ Interface with salvaged brushless ESC, radio receiver, and axis controls from a toy helicopter. Read analog pot/joystick inputs and replicate behavior over GPIO or software-defined control. Includes signal capture, pulse decoding, and control abstraction.

**TomTom Reverse Engineering & Repurpose Suite** `[planned]`  
_Project Focus:_ Repurpose a thrifted TomTom GPS device into a modular embedded platform. Learn from its hardware, interface with its components, and build working systems on top of salvaged parts.

**Erostek ET232 Controller Salvage & Reuse** `[planned]`  
_Project Focus:_ Investigate and reverse engineer the Erostek ET232 controller. Identify the function of each knob, switch, and port. Determine directionality of audio link and mic. Rebuild the enclosure with updated labeling, expose usable IO, and repurpose the unique form factor for a new embedded interface or testing tool.

**DSC PG9904P Motion Sensor Reverse Engineering** `[planned]`  
_Project Focus:_ Analyze behavior of the DSC PG9904P motion detector using logic analyzer and teardown methods. Identify activity from motion events, RF transmission, and general logic behavior. Document all subsystems and identify reuse opportunities.

---

### 🗂️ Infrastructure & Support Systems

**OTA Update Server** `[proposed]`  
_Project Focus:_ Build a simple server on a Raspberry Pi or Linux box to host firmware binaries, track version metadata, and serve updates to OTA-capable devices on request.

**Custom OpenBMC Build & Flash for Real-World Server Firmware** `[proposed]`  
_Project Focus:_ Build, modify, and deploy a full OpenBMC firmware image for emulated (QEMU) and physical hardware (e.g., Supermicro/AST2600). Learn embedded Linux via Yocto, device trees, bootloaders, and kernel customization. Target real-world firmware roles with layered milestone goals: QEMU-based test build, flashing physical board, customizing device tree and services, and full recovery workflows after intentional bricking.

---