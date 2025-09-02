#ifndef MOTOR_CONTROLLER_H
#define MOTOR_CONTROLLER_H

#include <stdint.h>
#include "arcade_drive.h"
#include "tb6612fng.h"
#include "esp_err.h"

/**
 * @brief Motor controller state
 */
typedef enum {
    MOTOR_STATE_DISABLED = 0,
    MOTOR_STATE_IDLE,
    MOTOR_STATE_RUNNING,
    MOTOR_STATE_BRAKING,
    MOTOR_STATE_ERROR
} motor_state_t;

/**
 * @brief Motor controller statistics
 */
typedef struct {
    uint32_t updates_received;
    uint32_t state_changes;
    uint32_t error_count;
    int16_t last_left_speed;
    int16_t last_right_speed;
} motor_stats_t;

/**
 * @brief Motor controller configuration
 */
typedef struct {
    tb6612fng_t* driver;           // Motor driver instance
    arcade_drive_t* arcade;        // Arcade drive calculator
    uint32_t update_period_ms;     // Minimum time between updates
    uint16_t safety_timeout_ms;    // Stop motors if no update received
} motor_controller_config_t;

/**
 * @brief Motor controller instance
 */
typedef struct {
    motor_controller_config_t config;
    motor_state_t state;
    motor_stats_t stats;
    uint32_t last_update_time;
    uint8_t initialized;
} motor_controller_t;

/**
 * @brief Initialize motor controller
 * @param controller Pointer to controller instance
 * @param config Pointer to configuration
 * @return ESP_OK on success
 */
esp_err_t motor_controller_init(motor_controller_t* controller, const motor_controller_config_t* config);

/**
 * @brief Process joystick input and update motors
 * @param controller Pointer to controller instance
 * @param x_input Joystick X-axis value
 * @param y_input Joystick Y-axis value
 * @return ESP_OK on success
 */
esp_err_t motor_controller_update(motor_controller_t* controller, uint16_t x_input, uint16_t y_input);

/**
 * @brief Enable motor controller
 * @param controller Pointer to controller instance
 * @return ESP_OK on success
 */
esp_err_t motor_controller_enable(motor_controller_t* controller);

/**
 * @brief Disable motor controller (motors enter standby)
 * @param controller Pointer to controller instance
 * @return ESP_OK on success
 */
esp_err_t motor_controller_disable(motor_controller_t* controller);

/**
 * @brief Emergency stop - immediately stop all motors
 * @param controller Pointer to controller instance
 * @return ESP_OK on success
 */
esp_err_t motor_controller_emergency_stop(motor_controller_t* controller);

/**
 * @brief Check for safety timeout and stop motors if needed
 * @param controller Pointer to controller instance
 * @return ESP_OK on success
 */
esp_err_t motor_controller_check_safety(motor_controller_t* controller);

/**
 * @brief Get current controller state
 * @param controller Pointer to controller instance
 * @return Current motor state
 */
motor_state_t motor_controller_get_state(const motor_controller_t* controller);

/**
 * @brief Get controller statistics
 * @param controller Pointer to controller instance
 * @return Pointer to statistics structure
 */
const motor_stats_t* motor_controller_get_stats(const motor_controller_t* controller);

#endif // MOTOR_CONTROLLER_H