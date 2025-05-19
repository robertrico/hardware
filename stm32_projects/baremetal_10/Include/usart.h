#include "stm32f4xx.h"
#include <stdint.h>

#define GPIOAEN (1U << 0) // Bit mask for enabling GPIOA (bit 0)
#define USART1EN (1U << 17) // Bit mask for enabling usart1 (bit 17) RM0383 §6.3.11

#define BAUD_RATE 19200 // Baud rate for USART communication
#define SYSTEM_CLOCK 72000000 // System clock frequency in Hz
#define APBCLOCK SYSTEM_CLOCK // APB clock frequency in Hz

#define CR1_TE (1U << 3) // Transmitter enable bit in USART_CR1 register RM0383 §19.6.4    
#define CR1_UE (1U << 13) // Transmitter enable bit in USART_CR1 register RM0383 §19.6.4    
#define SR_TXE (1U << 7) // Transmit data register empty flag in USART_SR register RM0383 §19.6.1

void usart1_write(int ch);
void usart1_init(void);