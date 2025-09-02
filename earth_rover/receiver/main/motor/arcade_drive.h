#ifndef ARCADE_DRIVE_H
#define ARCADE_DRIVE_H

#include <stdint.h>

/**
 * @brief Joystick configuration for arcade drive
 * Encapsulates all joystick-specific parameters
 */
typedef struct {
    uint16_t center_x;      // Center position for X-axis (forward/back)
    uint16_t center_y;      // Center position for Y-axis (left/right)
    uint16_t deadband_x;    // Deadband radius for X-axis
    uint16_t deadband_y;    // Deadband radius for Y-axis
    uint16_t max_value;     // Maximum ADC value
    uint16_t max_throttle_range;  // Maximum throttle range from center
    uint16_t max_steering_range;  // Maximum steering range from center
} joystick_config_t;

/**
 * @brief Motor output from arcade drive calculations
 * Represents the computed motor speeds and directions
 */
typedef struct {
    int16_t left_speed;     // Left motor speed (-1000 to 1000)
    int16_t right_speed;    // Right motor speed (-1000 to 1000)
    uint8_t enabled;        // 1 if motors should run, 0 if in deadband
} arcade_output_t;

/**
 * @brief Arcade drive context
 * Maintains configuration and state for arcade drive calculations
 */
typedef struct {
    joystick_config_t config;
    arcade_output_t output;
    uint8_t steering_reduction;  // Steering influence (0-100%)
    uint16_t min_motor_speed;     // Minimum speed to prevent stalling
} arcade_drive_t;

/**
 * @brief Initialize arcade drive with default configuration
 * @param drive Pointer to arcade drive context
 */
void arcade_drive_init(arcade_drive_t* drive);

/**
 * @brief Configure joystick parameters
 * @param drive Pointer to arcade drive context
 * @param config Pointer to joystick configuration
 */
void arcade_drive_configure(arcade_drive_t* drive, const joystick_config_t* config);

/**
 * @brief Calculate motor outputs from joystick inputs
 * @param drive Pointer to arcade drive context
 * @param x_input Raw X-axis joystick value (forward/reverse)
 * @param y_input Raw Y-axis joystick value (left/right)
 * @return Pointer to calculated motor outputs
 */
const arcade_output_t* arcade_drive_calculate(arcade_drive_t* drive, uint16_t x_input, uint16_t y_input);

/**
 * @brief Set steering reduction factor
 * @param drive Pointer to arcade drive context
 * @param reduction Steering reduction percentage (0-100)
 */
void arcade_drive_set_steering_reduction(arcade_drive_t* drive, uint8_t reduction);

/**
 * @brief Set minimum motor speed threshold
 * @param drive Pointer to arcade drive context
 * @param min_speed Minimum speed before motor stops (0-1000)
 */
void arcade_drive_set_min_speed(arcade_drive_t* drive, uint16_t min_speed);

#endif // ARCADE_DRIVE_H