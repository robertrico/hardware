# Raspberry Pi Pico PWM Motor Control with TB6612FNG

This project demonstrates low-level PWM control using the Raspberry Pi Pico (RP2040) and the pico-sdk. A TB6612FNG motor driver is driven with a clean, tunable PWM signal and controlled using GPIO pins. The goal was to fully understand the behavior of PWM from waveform to mechanical motion, using direct register-based control with live signal inspection via DSLogic Pro.

---

## Hardware

* **Board**: Raspberry Pi Pico
* **Motor Driver**: TB6612FNG
* **Power Source**: Bench supply or 2S/3S LiPo for VM
* **Load**: DC motor
* **Tools**:

  * DSLogic Pro (Logic Analyzer)
  * Breadboard and jumper wires
  * Optional oscilloscope for analog voltage inspection

---

## Project Goals

* Manually generate PWM using pico-sdk
* Understand the effect of wrap and channel level
* Visualize PWM signal with logic analyzer
* Control a DC motor’s direction and speed via TB6612FNG
* Use integer math only (avoid floats)
* Feel the effects of low vs high PWM resolution in real motion

---

## Key Concepts

* **PWM Frequency** = `PWM Clock / (wrap + 1)`
* **Duty Cycle** = `chan_level / (wrap + 1)`
* High `wrap` = smoother signal (higher resolution, lower frequency)
* Low `wrap` = choppy signal (lower resolution, higher frequency)
* TB6612FNG requires STBY HIGH to operate

---

## Wiring Summary

| Pico GPIO | TB6612FNG Pin | Purpose              |
| --------- | ------------- | -------------------- |
| GPIO16    | PWMA          | PWM signal           |
| GPIO17    | AIN1          | Direction            |
| GPIO18    | AIN2          | Direction            |
| GPIO19    | STBY          | Enable driver        |
| GND       | GND           | Common ground        |
| VM        | External V+   | Motor supply voltage |

---

## pico-sdk Code Snippet

```c
uint slice = pwm_gpio_to_slice_num(16);

// Initialize direction and standby pins
gpio_init(17); gpio_set_dir(17, GPIO_OUT); gpio_put(17, 1);
gpio_init(18); gpio_set_dir(18, GPIO_OUT); gpio_put(18, 0);
gpio_init(19); gpio_set_dir(19, GPIO_OUT); gpio_put(19, 1);  // STBY HIGH

// PWM setup
pwm_set_wrap(slice, 12499);  // ~10kHz @ 125MHz system clock
pwm_set_chan_level(slice, PWM_CHAN_A, 6250);  // 50% duty
pwm_set_enabled(slice, true);
```

---

## Logic Analyzer Notes

* Sampling at **50 kHz** is insufficient for a 10 kHz PWM
* Use **>= 1 MHz** sampling rate for clean visibility
* A 10 kHz PWM cycle needs at least 50–100 samples to be legible
* Duty cycle changes are clearly visible when wrap and level are high enough

---

## Observations

* Low wrap values (e.g. 3) create high frequency PWM that LEDs and motors can’t visually or physically respond to
* 12499 wrap gives 10 kHz PWM that is smooth for motor driving
* DSLogic confirms real output waveform matches software config
* Motor responds proportionally to duty cycle
* Direction flipping via GPIOs changes spin direction

---

## Reference Tools

* RP2040 Datasheet PWM section
* pico-sdk `pwm.h` functions
* TB6612FNG datasheet
* DSLogic Pro sampling best practices

# Commands
```bash
mkdir build
cd build
cmake ..
make
```

```bash
openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg -c "adapter speed 1000"
```

```bash
arm-none-eabi-gdb Wifi_Test_4.elf
```

```gdb
target remote localhost:3333
load
monitor reset init
continue

```bash
screen /dev/tty.usbmodem1202 115200