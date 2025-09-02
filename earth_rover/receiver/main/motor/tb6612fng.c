#include "tb6612fng.h"
#include "esp_log.h"

static const char* TAG = "TB6612FNG";

/**
 * @brief Set motor direction pins based on direction
 */
static esp_err_t set_motor_direction(gpio_num_t in1, gpio_num_t in2, motor_direction_t direction) {
    switch (direction) {
        case MOTOR_FORWARD:
            gpio_set_level(in1, 1);
            gpio_set_level(in2, 0);
            break;
        case MOTOR_REVERSE:
            gpio_set_level(in1, 0);
            gpio_set_level(in2, 1);
            break;
        case MOTOR_STOP:
        default:
            gpio_set_level(in1, 0);
            gpio_set_level(in2, 0);
            break;
    }
    return ESP_OK;
}

/**
 * @brief Configure GPIO pin as output
 */
static esp_err_t configure_gpio_output(gpio_num_t pin) {
    gpio_config_t io_conf = {
        .pin_bit_mask = (1ULL << pin),
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE
    };
    return gpio_config(&io_conf);
}

/**
 * @brief Initialize PWM channel for motor control
 */
static esp_err_t init_pwm_channel(ledc_channel_t channel, gpio_num_t pin, 
                                  ledc_timer_t timer, uint32_t duty) {
    ledc_channel_config_t ledc_channel = {
        .gpio_num = pin,
        .speed_mode = LEDC_LOW_SPEED_MODE,
        .channel = channel,
        .timer_sel = timer,
        .duty = duty,
        .hpoint = 0
    };
    return ledc_channel_config(&ledc_channel);
}

/**
 * @brief Set motor speed and direction
 */
static esp_err_t set_motor(const motor_config_t* motor, int16_t speed) {
    // Determine direction
    motor_direction_t direction = MOTOR_STOP;
    uint32_t duty = 0;
    
    if (speed > 0) {
        direction = MOTOR_FORWARD;
        duty = speed;  // speed is already 0-1000
    } else if (speed < 0) {
        direction = MOTOR_REVERSE;
        duty = -speed;  // Convert to positive
    } else {
        // Explicitly handle zero speed
        direction = MOTOR_STOP;
        duty = 0;
    }
    
    // Set direction pins
    set_motor_direction(motor->in1_pin, motor->in2_pin, direction);
    
    // Set PWM duty cycle
    if (direction == MOTOR_STOP || duty == 0) {
        // Force PWM to absolute 0 when stopped
        // This ensures the pin is at 0V, not just 0% duty cycle
        ledc_set_duty(LEDC_LOW_SPEED_MODE, motor->pwm_channel, 0);
        ledc_update_duty(LEDC_LOW_SPEED_MODE, motor->pwm_channel);
        
        // Optional: Stop the PWM timer completely for this channel
        // This ensures no switching noise at all
        ledc_stop(LEDC_LOW_SPEED_MODE, motor->pwm_channel, 0);  // 0 = output low
    } else {
        // Scale from 0-1000 to 0-8191 (13-bit resolution)
        if (duty > 1000) duty = 1000;
        uint32_t scaled_duty = (duty * 8191) / 1000;
        
        ledc_set_duty(LEDC_LOW_SPEED_MODE, motor->pwm_channel, scaled_duty);
        ledc_update_duty(LEDC_LOW_SPEED_MODE, motor->pwm_channel);
    }
    
    return ESP_OK;
}

esp_err_t tb6612fng_init(tb6612fng_t* driver) {
    esp_err_t ret;
    
    ESP_LOGI(TAG, "Initializing TB6612FNG motor driver");
    
    // Configure direction control pins
    ret = configure_gpio_output(driver->motor_a.in1_pin);
    if (ret != ESP_OK) return ret;
    
    ret = configure_gpio_output(driver->motor_a.in2_pin);
    if (ret != ESP_OK) return ret;
    
    ret = configure_gpio_output(driver->motor_b.in1_pin);
    if (ret != ESP_OK) return ret;
    
    ret = configure_gpio_output(driver->motor_b.in2_pin);
    if (ret != ESP_OK) return ret;
    
    // Configure standby pin
    ret = configure_gpio_output(driver->standby_pin);
    if (ret != ESP_OK) return ret;
    
    // Initialize motors to stopped state
    set_motor_direction(driver->motor_a.in1_pin, driver->motor_a.in2_pin, MOTOR_STOP);
    set_motor_direction(driver->motor_b.in1_pin, driver->motor_b.in2_pin, MOTOR_STOP);
    
    // Set standby to low (disabled) initially
    gpio_set_level(driver->standby_pin, 0);
    
    // Configure LEDC timer
    ledc_timer_config_t ledc_timer = {
        .speed_mode = LEDC_LOW_SPEED_MODE,
        .timer_num = LEDC_TIMER_0,
        .duty_resolution = driver->pwm_resolution,
        .freq_hz = driver->pwm_frequency,
        .clk_cfg = LEDC_AUTO_CLK
    };
    ret = ledc_timer_config(&ledc_timer);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to configure LEDC timer: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Configure PWM channels for both motors
    ret = init_pwm_channel(driver->motor_a.pwm_channel, driver->motor_a.pwm_pin, LEDC_TIMER_0, 0);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to configure PWM channel A: %s", esp_err_to_name(ret));
        return ret;
    }
    
    ret = init_pwm_channel(driver->motor_b.pwm_channel, driver->motor_b.pwm_pin, LEDC_TIMER_0, 0);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to configure PWM channel B: %s", esp_err_to_name(ret));
        return ret;
    }
    
    ESP_LOGI(TAG, "TB6612FNG initialized successfully");
    return ESP_OK;
}

esp_err_t tb6612fng_enable(const tb6612fng_t* driver, uint8_t enable) {
    gpio_set_level(driver->standby_pin, enable ? 1 : 0);
    ESP_LOGI(TAG, "Motor driver %s", enable ? "enabled" : "disabled");
    return ESP_OK;
}

esp_err_t tb6612fng_set_motor_a(const tb6612fng_t* driver, int16_t speed) {
    return set_motor(&driver->motor_a, speed);
}

esp_err_t tb6612fng_set_motor_b(const tb6612fng_t* driver, int16_t speed) {
    return set_motor(&driver->motor_b, speed);
}

esp_err_t tb6612fng_set_motors(const tb6612fng_t* driver, int16_t speed_a, int16_t speed_b) {
    esp_err_t ret = tb6612fng_set_motor_a(driver, speed_a);
    if (ret != ESP_OK) return ret;
    
    return tb6612fng_set_motor_b(driver, speed_b);
}

esp_err_t tb6612fng_stop(const tb6612fng_t* driver) {
    return tb6612fng_set_motors(driver, 0, 0);
}

esp_err_t tb6612fng_brake(const tb6612fng_t* driver) {
    // Short brake mode - both inputs high
    gpio_set_level(driver->motor_a.in1_pin, 1);
    gpio_set_level(driver->motor_a.in2_pin, 1);
    gpio_set_level(driver->motor_b.in1_pin, 1);
    gpio_set_level(driver->motor_b.in2_pin, 1);
    
    ESP_LOGI(TAG, "Motors braked");
    return ESP_OK;
}