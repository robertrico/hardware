#define ONE 256
#define ALPHA = 64

/**
 * @param input The current speed reading from the motor.
 * @param prev_output The previous output of the filter, which is used to calculate the new output.
 * @return The filtered speed reading, which is a smoothed version of the input.
 */
uint16_t lpf(uint16_t input, uint16_t prev_output);