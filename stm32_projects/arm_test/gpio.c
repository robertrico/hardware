#include "gpio.h"

#define GPIOAEN (1U << 0) // Bit mask for enabling GPIOA (bit 0)
#define GPIOBEN (1U << 1) // Bit mask for enabling GPIOB (bit 1)
#define GPIOCEN (1U << 2) // Bit mask for enabling GPIOC (bit 2)

// Bit Set Pins
#define BS_PIN5 (1U << 5)
#define BR_PIN5 (1U << 21)
#define BS_PIN2 (1U << 2)
#define BR_PIN2 (1U << 18)
#define BTN_PIN (1U << 13)

void led_init(void)
{
    // Enable clock access to GPIOA and GPIOB
    RCC->AHB1ENR |= GPIOAEN;
    RCC->AHB1ENR |= GPIOBEN;
    RCC->AHB1ENR |= GPIOCEN;

    // Set PA5 to output mode
    GPIOA->MODER |= (1U << 10); // Set mode to output
    GPIOA->MODER &= ~(1U << 11); // Clear mode bits

    // Set PB2 to output mode
    GPIOB->MODER |= (1U << 4); // Set mode to output
    GPIOB->MODER &= ~(1U << 5); // Clear mode bits

    // Set PC13 to input mode
    GPIOC->MODER &= ~(1U << 26); // Set mode to input
    GPIOC->MODER &= ~(1U << 27); // Clear pull-up/pull-down bits
}

void led_toggle(void)
{
    // Toggle PA5 (LED_PIN)
    GPIOA->ODR ^= BS_PIN5; // Toggle PA5
}

void led_toggleb(void)
{
    // Toggle PA5 (LED_PIN)
    GPIOB->ODR ^= BS_PIN2; // Toggle PB2
}

bool get_btn_state(void)
{
    // Read the state of PC13 (BTN_PIN)
    if ((GPIOC->IDR & BTN_PIN) == 0) // Check if button is pressed
    {
        return true; // Button is pressed
    }
    else
    {
        return false; // Button is not pressed
    }
}