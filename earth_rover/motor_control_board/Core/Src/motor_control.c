#include "motor_control.h"

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