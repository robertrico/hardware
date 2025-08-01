#include "motor_control.h"
#include <stdint.h>
#include "tim.h"

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
    
    // Determine direction and magnitude for each motor
    // Left motor
    if (left_raw > PWM_DEADBAND) {
        motor_ctrl->left_direction = 1;  // Forward
        motor_ctrl->left_pwm = (uint16_t)left_raw;
    } else if (left_raw < -PWM_DEADBAND) {
        motor_ctrl->left_direction = -1; // Reverse
        motor_ctrl->left_pwm = (uint16_t)(-left_raw);
    } else {
        motor_ctrl->left_direction = 0;  // Stop
        motor_ctrl->left_pwm = 0;
    }
    
    // Right motor
    if (right_raw > PWM_DEADBAND) {
        motor_ctrl->right_direction = 1;  // Forward
        motor_ctrl->right_pwm = (uint16_t)right_raw;
    } else if (right_raw < -PWM_DEADBAND) {
        motor_ctrl->right_direction = -1; // Reverse
        motor_ctrl->right_pwm = (uint16_t)(-right_raw);
    } else {
        motor_ctrl->right_direction = 0;  // Stop
        motor_ctrl->right_pwm = 0;
    }
    
    // Clamp PWM magnitudes to valid range
    if (motor_ctrl->left_pwm > (PWM_MAX - PWM_CENTER)) {
        motor_ctrl->left_pwm = PWM_MAX - PWM_CENTER;
    }
    if (motor_ctrl->right_pwm > (PWM_MAX - PWM_CENTER)) {
        motor_ctrl->right_pwm = PWM_MAX - PWM_CENTER;
    }
    
    // Apply low-pass filtering
    motor_ctrl->left_filtered = lpf(motor_ctrl->left_pwm, motor_ctrl->left_filtered);
    motor_ctrl->right_filtered = lpf(motor_ctrl->right_pwm, motor_ctrl->right_filtered);
}

/**
 * Set TB6612FNG motor direction using AIN1/AIN2 or BIN1/BIN2 pins
 */
void set_motor_direction(int8_t direction, uint16_t ain1_pin, uint16_t ain2_pin, GPIO_TypeDef* gpio_port) {
    switch (direction) {
        case 1:  // Forward: AIN1=1, AIN2=0
            HAL_GPIO_WritePin(gpio_port, ain1_pin, GPIO_PIN_SET);
            HAL_GPIO_WritePin(gpio_port, ain2_pin, GPIO_PIN_RESET);
            break;
        case -1: // Reverse: AIN1=0, AIN2=1
            HAL_GPIO_WritePin(gpio_port, ain1_pin, GPIO_PIN_RESET);
            HAL_GPIO_WritePin(gpio_port, ain2_pin, GPIO_PIN_SET);
            break;
        case 0:  // Stop: AIN1=0, AIN2=0 (short brake)
        default:
            HAL_GPIO_WritePin(gpio_port, ain1_pin, GPIO_PIN_RESET);
            HAL_GPIO_WritePin(gpio_port, ain2_pin, GPIO_PIN_RESET);
            break;
    }
}

/**
 * Apply motor control settings to TB6612FNG driver
 */
void apply_motor_control(motor_control_t* motor_ctrl) {
    // Set motor directions
    set_motor_direction(motor_ctrl->left_direction, MOTOR_AIN1_Pin, MOTOR_AIN2_Pin, MOTOR_AIN1_GPIO_Port);
    set_motor_direction(motor_ctrl->right_direction, MOTOR_BIN1_Pin, MOTOR_BIN2_Pin, MOTOR_BIN1_GPIO_Port);
    
    // Set PWM values (convert magnitude back to duty cycle for timer)
    // Scale the magnitude to full PWM range
    uint16_t left_duty = (motor_ctrl->left_filtered * 4095) / (PWM_MAX - PWM_CENTER);
    uint16_t right_duty = (motor_ctrl->right_filtered * 4095) / (PWM_MAX - PWM_CENTER);
    
    // Apply to timer compare registers
    TIM1->CCR1 = left_duty;   // Left motor PWM
    TIM1->CCR2 = right_duty;  // Right motor PWM
}