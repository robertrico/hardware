This README summarizes the working prototype of an ESP-NOW based remote control system built on ESP32-C3 devices. The system transmits a `LIGHT_ON` signal from a transmitter (TX) to a receiver (RX) over ESP-NOW protocol and toggles an LED accordingly.

---

## Development Setup

### Environment Preparation

1. **Install CMake 4.x if not already installed:**
    
    ```
    brew install cmake
    ```
    
2. **Override system CMake temporarily for ESP-IDF compatibility:**
    
    ```
    export PATH="/usr/local/Cellar/cmake/4.0.1/bin:$PATH"
    ```
    
3. **Source ESP-IDF environment:**
    
    ```
    source ../../esp-idf/export.sh
    ```
    
4. **Set the ESP32C3 as the build target:**
    
    ```
    idf.py set-target esp32c3
    ```
    
5. **Build the project:**
    
    ```
    idf.py build
    ```
    
6. **Flash the project to the board and open monitor:**
    
    ```
    idf.py -p /dev/cu.usbmodemXXXX flash monitor
    ```
    

### Quick Note

Example device output after flashing:

```
I (498) TX: My MAC: A0:85:E3:0C:A2:F4
I (478) RX: My MAC: A0:85:E3:0D:72:68
```

These MAC addresses are used to set up ESP-NOW peer connections.

---

## Communication Summary

- **TX device** sends `LIGHT_ON` messages over ESP-NOW when a button is pressed.
    
- **RX device** receives ESP-NOW payloads, and if the payload equals `LIGHT_ON`, it turns on an LED.
    
- Proper string comparison on the RX requires handling the null terminator issue carefully.
    

---

## Practical Outcomes

- **Antenna**: Attaching the external antenna massively improved range and reliability.
    
- **Reliability**: Without an antenna, ESP-NOW barely worked at short range. With antenna, normal house-range operation is achievable.
    
- **Latency**: Extremely low, near instantaneous toggling.
    

---

## Real-World Next Steps

1. **Button Parsing**:
    
    - Since multiple buttons are on a shared line, additional logic must be implemented either by:
        
        - Timing analysis
            
        - Encoding states into payloads
            
        - Introducing GPIO expander chips if necessary
            
2. **OTA Updates**:
    
    - The groundwork for Over-the-Air firmware updates (OTA) has been laid out, including manual bootstrapping routines for memory and vector reinitialization (reference materials: `linker.md`, `ota_bootstrap.md`).
        
3. **LoRa for Rover Project**:
    
    - LoRa will be used for long-range communications, such as hundreds of yards (and beyond), necessary for future rover and field tool deployments.
        
4. **NRF24L01 Exploration**:
    
    - Cheap and decent for DIY RC projects.
        
    - Lower power and narrower bandwidth than Wi-Fi, good for reliable command/control but not streaming data.
        

---

## Version Control Note

You **should ignore** the `/managed_components` directory created by ESP-IDF in version control (`.gitignore`) because it gets auto-generated and rebuilt.

Example `.gitignore` addition:

```
/managed_components
```

---

## Closing Thoughts

This is a very solid, simple, and extensible base to continue building homebrew R/C, automation, and telemetry systems.

You have built:

- Basic wireless control
    
- A real-world wireless stack (ESP-NOW)
    
- Correct MAC address management
    
- A starting point for OTA firmware upgrades
    

Next, you can expand:

- RF exploration (NRF24L01)
    
- Robust OTA
    
- Rover tool arm automation
    
- Light drone-based scouting (optional)
    