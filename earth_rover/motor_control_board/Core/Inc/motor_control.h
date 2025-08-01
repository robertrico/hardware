#define ONE 256
#define ALPHA 64

// PWM limits for clamping (neutral zone)
#define PWM_MIN 2000
#define PWM_MAX 2400
#define PWM_CENTER 2200
#define PWM_DEADBAND 50

// Motor control structure for differential steering
typedef struct {
    uint16_t left_pwm;
    uint16_t right_pwm;
    uint16_t left_filtered;
    uint16_t right_filtered;
} motor_control_t;

/**
 * @param input The current speed reading from the motor.
 * @param prev_output The previous output of the filter, which is used to calculate the new output.
 * @return The filtered speed reading, which is a smoothed version of the input.
 */
uint16_t lpf(uint16_t input, uint16_t prev_output);

/**
 * @param pwm_value The PWM value to clamp
 * @return Clamped PWM value between PWM_MIN and PWM_MAX, or 0 if in deadband
 */
uint16_t clamp_pwm(uint16_t pwm_value);

/**
 * @param forward_reverse Forward/reverse input (potentiometer value)
 * @param left_right Left/right input (potentiometer value) 
 * @param motor_ctrl Output structure with left and right PWM values
 */
void arcade_drive(uint16_t forward_reverse, uint16_t left_right, motor_control_t* motor_ctrl);