## Zephyr PWM Example: main.c Breakdown

### 1. PWM Device Spec from DeviceTree

```c
static const struct pwm_dt_spec pwm_led0 = PWM_DT_SPEC_GET(DT_ALIAS(pwmled0));
```

- `DT_ALIAS(pwmled0)`: Resolves the alias `pwmled0` defined in the overlay.
    
- `PWM_DT_SPEC_GET(...)`: Expands to a `pwm_dt_spec` struct with:
    
    - `.dev`: pointer to the PWM device binding.
        
    - `.channel`: numeric PWM channel.
        
    - `.flags`: PWM polarity/settings.
        

### 2. Period Constants

```c
#define MIN_PERIOD PWM_SEC(1U) / 128U
#define MAX_PERIOD PWM_SEC(1U)
```

- `MIN_PERIOD`: Minimum period = 1 s / 128 = ~7.8 ms.
    
- `MAX_PERIOD`: Starting max period = 1 s.
    

### 3. Device Readiness Check

```c
    if (!pwm_is_ready_dt(&pwm_led0)) {
        printk("Error: PWM device %s is not ready\n",
               pwm_led0.dev->name);
        return 0;
    }
```

- Verifies the PWM device binding is ready before use.
    
- On failure, prints device name and exits.
    

### 4. Calibration Loop

```c
    printk("Calibrating for channel %d...\n", pwm_led0.channel);
    max_period = MAX_PERIOD;
    while (pwm_set_dt(&pwm_led0, max_period, max_period / 2U)) {
        max_period /= 2U;
        if (max_period < (4U * MIN_PERIOD)) {
            printk("Error: PWM device does not support a period at least %lu\n",
                   4U * MIN_PERIOD);
            return 0;
        }
    }
```

- **Goal**: Find the largest period the hardware supports.
    
- Attempts to set a 50% duty cycle at `max_period`. If `pwm_set_dt()` fails, halves `max_period` and retries.
    
- Ensures at least `4 * MIN_PERIOD` remains to allow period variation.
    

### 5. Initial PWM Setup

```c
    period = max_period;
    pwm_set_dt(&pwm_led0, PWM_MSEC(1), PWM_MSEC(0.5));
```

- Sets a quick 1 ms period and 0.5 ms pulse (50% duty) before entering the loop.
    

### 6. Main Control Loop

```c
    while (1) {
        ret = pwm_set_dt(&pwm_led0, period, period / 2U);
        if (ret) {
            printk("Error %d: failed to set pulse width\n", ret);
            return 0;
        }
        printk("Using period %d\n", period);

        period = dir ? (period * 2U) : (period / 2U);
        if (period > max_period) {
            period = max_period / 2U;
            dir = 0U;
        } else if (period < MIN_PERIOD) {
            period = MIN_PERIOD * 2U;
            dir = 1U;
        }

        k_sleep(K_SECONDS(4U));
    }
    return 0;
}
```

- Updates PWM at 50% duty with the current `period`.
    
- Logs the period each cycle.
    
- Adjusts `period` up or down by factor of two, reversing direction at the calibrated limits.
    
- Sleeps 4 s between updates.
    

---

## DeviceTree Overlay Breakdown

```dts
&pwm {
    status = "okay";
};
```

- **Enables** the PWM controller node in the SoC definition.
    

```dts
&pinctrl {
    pwm_gpio2_default: pwm_gpio2_default {
        group1 {
            pinmux = <PWM_1A_P2>;
        };
    };
};
```

- Defines a pinctrl node named `pwm_gpio2_default`.
    
- Sets `PWM_1A_P2` function on pin group `group1` (i.e., GPIO pin 2 configured as PWM channel A).
    

```dts
&pwm {
    pinctrl-0 = <&pwm_gpio2_default>;
    pinctrl-names = "default";
};
```

- Attaches the pinctrl configuration to the PWM device under the "default" state.
    

```dts
/ {
    pwmleds {
        compatible = "pwm-leds";
        pwm_led_0: pwm_led_0 {
            pwms = <&pwm 2 PWM_MSEC(20) PWM_POLARITY_NORMAL>;
            label = "PWM LED 0";
        };
    };

    aliases {
        pwmled0 = &pwm_led_0;
    };
};
```

- **Root-level** node `pwmleds` with `compatible = "pwm-leds"` selects the PWM-LED driver.
    
- Child `pwm_led_0`:
    
    - `pwms = <&pwm 2 PWM_MSEC(20) PWM_POLARITY_NORMAL>`:
        
        - `&pwm`: reference to the enabled PWM controller.
            
        - `2`: PWM channel number (matches `pwm_led0.channel` in C).
            
        - `PWM_MSEC(20)`: default 20 ms period (50 Hz typical LED blink rate).
            
        - `PWM_POLARITY_NORMAL`: active-high output.
            
    - `label`: human-readable name for the LED device.
        
- `aliases { pwmled0 = &pwm_led_0; }` creates alias `pwmled0` used by `DT_ALIAS` in code.
    

---

**Mapping to `main.c`:**

- The C code’s `PWM_DT_SPEC_GET(DT_ALIAS(pwmled0))` retrieves:
    
    - `dev` → the driver binding for the above `pwm_led_0` node.
        
    - `channel = 2` → matches the `pwms` channel.
        
    - `flags` → includes `PWM_POLARITY_NORMAL`.
        
- Pin configuration done by the pinctrl settings ensures GPIO2 is driven by the PWM peripheral.
    
- Together, the DT overlay and C code form a hardware abstraction: the application never hardcodes pin numbers, only DT aliases and spec macros.