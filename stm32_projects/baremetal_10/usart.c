#include "usart.h"

static void usart1_set_baud_rate(uint32_t clk, uint32_t baud_rate);

void usart1_init(void)
{
    RCC->AHB1ENR |= RCC_AHB1ENR_GPIOAEN; // Enable GPIOA clock
    RCC->APB2ENR |= RCC_APB2ENR_USART1EN;

    // Set PA to Alt Function Mode - 10 
    GPIOA->MODER |= (1U << 19); // Set bit 19
    GPIOA->MODER &= ~(1U << 18); // Clear bit 18

    // Set PA9 to AF7 (usart1) - 0111 RM0383 §8.4.10
    GPIOA->AFR[1] &= ~(0xF << 4);      // Clear bits 7-4
    GPIOA->AFR[1] |= (0x7 << 4);       // Set bits 7-4 to 0111 (AF7)

    // set baud rate
    usart1_set_baud_rate(APBCLOCK, BAUD_RATE);
    //USART1->BRR = 72000000 / 115200; // = 7500 = 0x1D4C

    // Set Direction
    USART1->CR1 |= 0x2008;
    for (volatile int i = 0; i < 1000; ++i);
}

void usart1_write(int ch) 
{
    while(!(USART1->SR & SR_TXE)) {}

    USART1->DR = (ch);
}

static uint16_t compute_usart_bd(uint32_t clk, uint32_t baud_rate)
{
    return (( clk + (baud_rate/2U) ) / baud_rate );
}

static void usart1_set_baud_rate(uint32_t clk, uint32_t baud_rate)
{
    USART1->BRR = compute_usart_bd(clk, baud_rate);
}



