# PWM Motor Control Project Using Zephyr RTOS

## Objective

Create a Zephyr RTOS project that uses PWM (Pulse Width Modulation) to control a DC motor via a motor driver. This project demonstrates PWM output and GPIO control to drive a motor forward and stop it at regular intervals.

---

## Hardware Requirements

- **Microcontroller**: Raspberry Pi Pico (RP2040) or any Zephyr-supported MCU
    
- **Motor Driver**: TB6612FNG or equivalent
    
- **Motor**: Small DC motor
    
- **Power Supply**: Sufficient to drive the motor (e.g., 5V or 6V)
    
- **Connections**:
    
    - **PWM Input** to motor driver
        
    - **Direction Control Pins (IN1, IN2)**
        
    - **Standby Pin (STBY)**
        
    - Common **GND** across MCU, motor driver, and motor power supply
        

---

## Software Requirements

- Zephyr Project Setup (with west, Zephyr SDK installed)
    
- Python virtual environment activated
    
- Board Support Package for selected MCU
    

---

## Project Structure

```bash
pwm_motor_project/
├── app/
│   ├── src/
│   │   └── main.c
│   ├── boards/
│   │   └── rpi_pico.overlay
│   ├── CMakeLists.txt
│   └── prj.conf
├── CMakeLists.txt
```

---

## Device Tree Overlay Example (`app/boards/rpi_pico.overlay`)

```dts
&pwm0 {
    status = "okay";
};

/ {
    aliases {
        motor_pwm = &pwm0;
    };

    motor_control: motor_control {
        compatible = "gpio-keys";
        ain1-gpios = <&gpio0 14 GPIO_ACTIVE_HIGH>;
        ain2-gpios = <&gpio0 15 GPIO_ACTIVE_HIGH>;
        stby-gpios = <&gpio0 16 GPIO_ACTIVE_HIGH>;
    };
};
```

---

## Project Configuration (`app/prj.conf`)

```conf
# Core settings
CONFIG_MAIN_STACK_SIZE=1024
CONFIG_GPIO=y
CONFIG_PWM=y

# Optional debugging
CONFIG_LOG=y
CONFIG_LOG_DEFAULT_LEVEL=3
```

---

## Application Code (`app/src/main.c`)

```c
#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/drivers/pwm.h>

#define PWM_CTLR_NODE    DT_ALIAS(motor_pwm)
#define AIN1_PIN         14
#define AIN2_PIN         15
#define STBY_PIN         16
#define PWM_CHANNEL      0
#define PWM_PERIOD_USEC  20000 // 20 ms period (~50 Hz)

static const struct device *pwm_dev;
static const struct device *gpio_dev;

void setup_gpio(void)
{
    gpio_dev = DEVICE_DT_GET(DT_NODELABEL(gpio0));
    if (!device_is_ready(gpio_dev)) {
        printk("GPIO device not ready\n");
        return;
    }

    gpio_pin_configure(gpio_dev, AIN1_PIN, GPIO_OUTPUT_ACTIVE);
    gpio_pin_configure(gpio_dev, AIN2_PIN, GPIO_OUTPUT_ACTIVE);
    gpio_pin_configure(gpio_dev, STBY_PIN, GPIO_OUTPUT_ACTIVE);

    gpio_pin_set(gpio_dev, STBY_PIN, 1); // Enable motor driver
}

void motor_forward(void)
{
    gpio_pin_set(gpio_dev, AIN1_PIN, 1);
    gpio_pin_set(gpio_dev, AIN2_PIN, 0);
}

void motor_stop(void)
{
    gpio_pin_set(gpio_dev, AIN1_PIN, 0);
    gpio_pin_set(gpio_dev, AIN2_PIN, 0);
}

void main(void)
{
    setup_gpio();
    pwm_dev = DEVICE_DT_GET(PWM_CTLR_NODE);

    if (!device_is_ready(pwm_dev)) {
        printk("PWM device not ready\n");
        return;
    }

    motor_forward();

    while (1) {
        pwm_pin_set_usec(pwm_dev, PWM_CHANNEL, PWM_PERIOD_USEC, PWM_PERIOD_USEC / 2U, 0); // 50% duty
        k_sleep(K_SECONDS(2));

        pwm_pin_set_usec(pwm_dev, PWM_CHANNEL, PWM_PERIOD_USEC, 0, 0); // 0% duty
        motor_stop();
        k_sleep(K_SECONDS(2));

        motor_forward();
    }
}
```

---

## Build and Flash Commands

```bash
source zephyr/zephyr-env.sh
west build -b rpi_pico app/
west flash
```

---

## Notes

- Adjust `PWM_CHANNEL` based on your MCU's PWM output capabilities.
    
- Ensure the motor supply voltage matches the motor and driver specs.
    
- Always use a common ground between the MCU, motor driver, and motor supply.
    
- You can extend this by implementing speed changes, reversing direction, or adding input buttons.
    

---

## Best Practices

- Keep hardware abstraction (GPIO, PWM setup) modular.
    
- Use DeviceTree (`gpio_dt_spec`, `pwm_dt_spec`) for portability.
    
- Enable logging for debugging hardware states.
    
- Version control the `app/` directory independently from the SDK.