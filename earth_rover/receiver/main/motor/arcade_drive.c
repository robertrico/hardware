#include "arcade_drive.h"
#include <stdlib.h>

/**
 * @brief Clamp a value between min and max
 */
static int16_t clamp_int16(int16_t value, int16_t min, int16_t max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
}

/**
 * @brief Check if joystick is in deadband
 */
static uint8_t is_in_deadband(const arcade_drive_t* drive, uint16_t x_input, uint16_t y_input) {
    const joystick_config_t* cfg = &drive->config;
    
    return (x_input > (cfg->center_x - cfg->deadband_x) && 
            x_input < (cfg->center_x + cfg->deadband_x) &&
            y_input > (cfg->center_y - cfg->deadband_y) && 
            y_input < (cfg->center_y + cfg->deadband_y));
}

/**
 * @brief Convert joystick input to centered signed value
 */
static int16_t joystick_to_centered(uint16_t input, uint16_t center, uint16_t max_range, uint8_t invert) {
    int16_t centered = invert ? (center - (int16_t)input) : ((int16_t)input - center);
    return clamp_int16(centered, -max_range, max_range);
}

/**
 * @brief Scale value from input range to output range
 */
static int16_t scale_value(int16_t value, int16_t in_max, int16_t out_max) {
    return (value * out_max) / in_max;
}

void arcade_drive_init(arcade_drive_t* drive) {
    // Default configuration based on typical joystick values
    drive->config.center_x = 2220;
    drive->config.center_y = 2195;
    drive->config.deadband_x = 300;
    drive->config.deadband_y = 300;
    drive->config.max_value = 4095;
    drive->config.max_throttle_range = 1720;
    drive->config.max_steering_range = 1900;
    
    // Default behavior settings
    drive->steering_reduction = 25;  // 25% steering influence
    drive->min_motor_speed = 30;     // Minimum PWM to prevent stalling
    
    // Initialize output
    drive->output.left_speed = 0;
    drive->output.right_speed = 0;
    drive->output.enabled = 0;
}

void arcade_drive_configure(arcade_drive_t* drive, const joystick_config_t* config) {
    drive->config = *config;
}

const arcade_output_t* arcade_drive_calculate(arcade_drive_t* drive, uint16_t x_input, uint16_t y_input) {
    // Check deadband first - HARD STOP when in deadband
    if (is_in_deadband(drive, x_input, y_input)) {
        // Force absolute zero - no PWM signal at all
        drive->output.left_speed = 0;
        drive->output.right_speed = 0;
        drive->output.enabled = 0;
        return &drive->output;
    }
    
    // Convert to centered values
    // Note: X-axis is inverted (low values = forward)
    int16_t throttle = joystick_to_centered(x_input, drive->config.center_x, 
                                           drive->config.max_throttle_range, 1);
    int16_t steering = joystick_to_centered(y_input, drive->config.center_y,
                                           drive->config.max_steering_range, 0);
    
    // Scale to motor range (-1000 to 1000)
    throttle = scale_value(throttle, drive->config.max_throttle_range, 1000);
    steering = scale_value(steering, drive->config.max_steering_range, 1000);
    
    // Apply steering reduction
    steering = (steering * drive->steering_reduction) / 100;
    
    // Calculate differential drive
    int16_t left_raw = throttle + steering;
    int16_t right_raw = throttle - steering;
    
    // Clamp to valid range
    left_raw = clamp_int16(left_raw, -1000, 1000);
    right_raw = clamp_int16(right_raw, -1000, 1000);
    
    // Apply minimum speed threshold
    if (abs(left_raw) < drive->min_motor_speed) {
        left_raw = 0;
    }
    if (abs(right_raw) < drive->min_motor_speed) {
        right_raw = 0;
    }
    
    // Update output
    drive->output.left_speed = left_raw;
    drive->output.right_speed = right_raw;
    drive->output.enabled = (left_raw != 0 || right_raw != 0);
    
    return &drive->output;
}

void arcade_drive_set_steering_reduction(arcade_drive_t* drive, uint8_t reduction) {
    if (reduction <= 100) {
        drive->steering_reduction = reduction;
    }
}

void arcade_drive_set_min_speed(arcade_drive_t* drive, uint16_t min_speed) {
    if (min_speed <= 1000) {
        drive->min_motor_speed = min_speed;
    }
}