#include "tim.h"

#define TIM2EN (1U << 0) 
#define CR1_CEN (1U << 0) 

void tim2_1hz_init(void)
{
    // Enable clock access to TIM2
    RCC->APB1ENR |= TIM2EN; // Enable TIM2 clock

    // Configure TIM2 for 1 Hz
    TIM2->PSC = 1600 - 1; // Set prescaler to 16000 (assuming 16 MHz clock)
    TIM2->ARR = 5000 - 1; // Set auto-reload value to 1000

    TIM2->CNT = 0; // Reset counter
    TIM2->CR1 = CR1_CEN; // Enable TIM2
}
