#ifndef TB6612FNG_H
#define TB6612FNG_H

#include <stdint.h>
#include "driver/gpio.h"
#include "driver/ledc.h"

/**
 * @brief Motor direction enumeration
 */
typedef enum {
    MOTOR_STOP = 0,
    MOTOR_FORWARD = 1,
    MOTOR_REVERSE = -1
} motor_direction_t;

/**
 * @brief Single motor configuration
 */
typedef struct {
    gpio_num_t in1_pin;        // Direction control pin 1
    gpio_num_t in2_pin;        // Direction control pin 2
    gpio_num_t pwm_pin;        // PWM output pin
    ledc_channel_t pwm_channel; // PWM channel for speed control
} motor_config_t;

/**
 * @brief TB6612FNG dual motor driver
 */
typedef struct {
    motor_config_t motor_a;    // Motor A configuration
    motor_config_t motor_b;    // Motor B configuration
    gpio_num_t standby_pin;    // Standby pin (active low)
    uint32_t pwm_frequency;    // PWM frequency in Hz
    ledc_timer_bit_t pwm_resolution; // PWM resolution
    uint32_t max_duty;         // Maximum duty cycle value
} tb6612fng_t;

/**
 * @brief Initialize TB6612FNG motor driver
 * @param driver Pointer to driver instance
 * @return ESP_OK on success
 */
esp_err_t tb6612fng_init(tb6612fng_t* driver);

/**
 * @brief Enable or disable the motor driver
 * @param driver Pointer to driver instance
 * @param enable true to enable, false for standby
 * @return ESP_OK on success
 */
esp_err_t tb6612fng_enable(const tb6612fng_t* driver, uint8_t enable);

/**
 * @brief Set motor A speed and direction
 * @param driver Pointer to driver instance
 * @param speed Motor speed (-1000 to 1000)
 * @return ESP_OK on success
 */
esp_err_t tb6612fng_set_motor_a(const tb6612fng_t* driver, int16_t speed);

/**
 * @brief Set motor B speed and direction
 * @param driver Pointer to driver instance
 * @param speed Motor speed (-1000 to 1000)
 * @return ESP_OK on success
 */
esp_err_t tb6612fng_set_motor_b(const tb6612fng_t* driver, int16_t speed);

/**
 * @brief Set both motors simultaneously
 * @param driver Pointer to driver instance
 * @param speed_a Motor A speed (-1000 to 1000)
 * @param speed_b Motor B speed (-1000 to 1000)
 * @return ESP_OK on success
 */
esp_err_t tb6612fng_set_motors(const tb6612fng_t* driver, int16_t speed_a, int16_t speed_b);

/**
 * @brief Stop both motors immediately
 * @param driver Pointer to driver instance
 * @return ESP_OK on success
 */
esp_err_t tb6612fng_stop(const tb6612fng_t* driver);

/**
 * @brief Brake both motors (short brake mode)
 * @param driver Pointer to driver instance
 * @return ESP_OK on success
 */
esp_err_t tb6612fng_brake(const tb6612fng_t* driver);

#endif // TB6612FNG_H