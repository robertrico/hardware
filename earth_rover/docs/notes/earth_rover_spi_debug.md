**Earth Rover SPI Communication Debug Summary**

**Subsystem:** SPI Communication (ESP32-C3 Master to STM32L4 Slave)

---

**Achievements:**
- Manual CS control implemented on ESP32-C3
- EXTI-based DMA arming functional on STM32L4
- Confirmed SPI DMA transfer completion via HAL_SPI_RxCpltCallback
- Valid SPI transfers received when sufficient delay (40 µs) added between CS low and spi_device_transmit()
- FreeRTOS ISR queue issue resolved by passing data buffer by value (not pointer)
- Logic analyzer confirms EXTI and SPI callbacks execute in expected order when timing allows
- Confirmed correct byte ordering (LSB-first) and buffer reconstruction logic on STM32

---

**Roadblocks and Observations:**
- Reducing CS-to-transmit delay to 20 µs results in misaligned or corrupted SPI data
- DMA transfers occasionally complete with unexpected or stale data
- Values received by STM32 do not consistently match ESP32 send log
- Logging delay and potentiometer value variability complicate debug visibility
- Race condition observed between EXTI and RxCplt callbacks if timing is tight
- Use of stack-allocated payload buffer in ESP-NOW ISR led to corrupted data in SPI layer

---

**Current Status:**
- Manual CS and EXTI-based DMA triggering validated as workable model
- Timing remains critical; requires >= 30-40 µs for stable operation
- Packetization and framing structure proposed to resolve alignment issues in future

