## Overview

This system architecture describes a modular, resilient embedded system where a Raspberry Pi 5 acts as a **passive supervisor**, while dedicated microcontrollers (MCUs) handle real-time control and communication tasks. The Pi observes system health, logs telemetry, and intervenes only in exceptional conditions (e.g., safety shutdowns).

The design prioritizes real-time reliability, modularity, and fault tolerance, typical of advanced robotics, industrial controllers, and autonomous platforms.

---

## System Components

### 1. Motor Controller MCU

- **Role**: Real-time control of motors, servos, encoders, or actuators.
    
- **Typical Devices**: RP2040, STM32, ATmega328P.
    
- **Responsibilities**:
    
    - Drive motors.
        
    - Implement PID loops and motion profiles.
        
    - Monitor currents, thermal sensors, encoder feedback.
        
    - Respond to commands from Comms MCU.
        

### 2. Communications MCU

- **Role**: Handle wireless communications.
    
- **Typical Devices**: ESP32 (ESP-NOW, Wi-Fi), NRF24L01 modules.
    
- **Responsibilities**:
    
    - Maintain peer-to-peer or network connections.
        
    - Parse incoming remote control commands.
        
    - Forward control instructions to Motor MCU.
        
    - Optionally relay telemetry back to remote controllers.
        

### 3. Raspberry Pi 5 (Supervisor)

- **Role**: High-level observation and intervention.
    
- **Responsibilities**:
    
    - Log system events and telemetry.
        
    - Detect faults via GPIO interrupts or periodic queries.
        
    - Perform emergency actions (e.g., stop motors).
        
    - Manage OTA (Over-The-Air) updates to MCUs.
        
    - Handle user interfaces or cloud communication if needed.
        

---

## Communication Pathways

|Pathway|Method|Purpose|
|:--|:--|:--|
|Comms MCU to Motor MCU|UART/SPI/I2C|Send motion commands, receive status.|
|Motor MCU to Pi 5|UART/SPI + GPIO interrupt|Forward telemetry, error notifications.|
|Comms MCU to Pi 5|Optional UART/SPI|Provide wireless status updates.|
|Remote Control to Comms MCU|Wireless (ESP-NOW, RF)|Direct user control input.|

---

## Event Handling Example

**Normal Operation:**

- Remote control issues a "move forward" command.
    
- Comms MCU forwards the command via UART to Motor MCU.
    
- Motor MCU controls the motors.
    
- Motor MCU periodically sends telemetry (speed, current) to Pi 5.
    

**Fault Scenario:**

- Motor MCU detects a motor stall.
    
- GPIO interrupt line to Pi 5 is triggered.
    
- Pi 5 reads detailed fault data over UART.
    
- Pi 5 optionally commands an immediate system stop.
    

---

## Physical Connections

- **UART or SPI** between MCUs.
    
- **Dedicated GPIO interrupt line(s)** from Motor MCU (and/or Comms MCU) to Pi 5.
    
- **Power considerations**:
    
    - MCUs powered independently to survive Pi reboots.
        
    - Optional hardware watchdogs on MCUs.
        

---

## Key Design Principles

- **Hardwired critical paths**: Control flows independent of Pi uptime.
    
- **Pi as passive arbiter**: Observes, logs, and intervenes without being in the critical control path.
    
- **Interrupt-driven communication**: Pi responds to system changes efficiently without constant polling.
    
- **Loose coupling**: Each module can operate independently if needed.
    
- **Fault resilience**: Wireless failures or Pi crashes don't compromise basic motor control.
    

---

## Future Enhancements

- Add multi-node communication (multiple motor nodes, multiple comms nodes).
    
- Layer a software message bus on the Pi for modular telemetry handling.
    
- Implement automatic reconnection logic for wireless links.
    
- Introduce Pi-driven mission planning or AI navigation modules.
    
- Extend OTA capabilities to support firmware upgrades for all MCUs.
    

---

## Conclusion

This modular embedded architecture ensures that real-time tasks remain reliable and responsive, while supervisory functions like logging, high-level decision making, and remote updates are layered safely and flexibly. The result is a system robust enough for real-world robotics, long-range rovers, industrial automation, and mission-critical embedded platforms.