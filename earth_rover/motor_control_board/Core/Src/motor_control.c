#include "motor_control.h"
#include <stdint.h>

/**
 * The First-Order Low-Pass Filter (FOLPF) is used to smooth the motor speed readings.
 * It takes the current speed and applies a smoothing factor to it.
 * The smoothing factor is defined as a constant, which can be adjusted to change the responsiveness of
 * the filter.
 */
uint16_t lpf(uint16_t input, uint16_t prev_output) {
    // y[n] = (ALPHA * input + (ONE - ALPHA) * prev_output) / ONE
    return (uint16_t)(((ALPHA * input) + ((ONE - ALPHA) * prev_output)) >> 8);
}

/**
 * Clamp PWM values to valid range and implement deadband
 */
uint16_t clamp_pwm(uint16_t pwm_value) {
    // Check if in deadband (neutral zone)
    if (pwm_value >= (PWM_CENTER - PWM_DEADBAND) && 
        pwm_value <= (PWM_CENTER + PWM_DEADBAND)) {
        return 0; // Stop motor
    }
    
    // Clamp to valid PWM range
    if (pwm_value < PWM_MIN) {
        return PWM_MIN;
    }
    if (pwm_value > PWM_MAX) {
        return PWM_MAX;
    }
    
    return pwm_value;
}

/**
 * Arcade-style differential steering
 * Takes forward/reverse and left/right inputs and converts to left/right motor PWM
 */
void arcade_drive(uint16_t forward_reverse, uint16_t left_right, motor_control_t* motor_ctrl) {
    // Convert inputs to signed values centered around 0
    int16_t throttle = (int16_t)forward_reverse - PWM_CENTER;
    int16_t steering = (int16_t)left_right - PWM_CENTER;
    
    // Apply deadband to inputs
    if (throttle > -PWM_DEADBAND && throttle < PWM_DEADBAND) {
        throttle = 0;
    }
    if (steering > -PWM_DEADBAND && steering < PWM_DEADBAND) {
        steering = 0;
    }
    
    // Calculate differential steering
    int16_t left_raw = throttle + steering;
    int16_t right_raw = throttle - steering;
    
    // Convert back to PWM values centered around PWM_CENTER
    uint16_t left_pwm = (uint16_t)(left_raw + PWM_CENTER);
    uint16_t right_pwm = (uint16_t)(right_raw + PWM_CENTER);
    
    // Apply clamping and store results
    motor_ctrl->left_pwm = clamp_pwm(left_pwm);
    motor_ctrl->right_pwm = clamp_pwm(right_pwm);
    
    // Apply low-pass filtering
    motor_ctrl->left_filtered = lpf(motor_ctrl->left_pwm, motor_ctrl->left_filtered);
    motor_ctrl->right_filtered = lpf(motor_ctrl->right_pwm, motor_ctrl->right_filtered);
}