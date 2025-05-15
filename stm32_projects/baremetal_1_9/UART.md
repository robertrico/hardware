# STM32F411RE UART Logic Analyzer Pattern Test

## Objective

Israel Gbati's book "Bare-Metal Embedded C Programming" has been a great book so far. However, his examples for the understanding, building and testing the UART peripheral fall short. In this project, I aim to better understand UART from a Bare-Metal fundamental understanding. In doing so, I hope to gain a better understanding of embedded peripherals, experience developing C low-level projects and to further my experience with a Logic Analyzer. The objective is to ransmit a recognizable UART pattern (`U`, `A`, `U`, `A`, ...) directly via USART2 registers to confirm proper peripheral configuration using a logic analyzer. Avoid all system libraries and runtime abstractions.

---

## Hardware Requirements

- STM32F411RE (Nucleo board)
- Logic analyzer (DSLogic Pro)
- Jumper wire from TX pin (PA2 / USART2 TX) to logic analyzer input
- GND connection between STM32 and analyzer

---

## Pattern

Characters:
- `U` = `0x55` = `01010101`
- `A` = `0x41` = `01000001`

This bit pattern is perfect for validating UART waveform with a logic analyzer.

---

## Project Structure

```
src/
├── main.c
├── uart.c
├── uart.h
├── startup_stm32f411xe.s
├── linker.ld
├── CMakeLists.txt
```

---

## uart.h

```c
// Declare UART init and send functions
void uart_init(void);
void uart_send_char(char c);
void uart_send_string(const char* str);
```

---

## uart.c (Pseudo Code)

```c
function uart_init():
    // Enable GPIOA peripheral clock (bit 0)
    set_bit(RCC->AHB1ENR, 0)

    // Enable USART2 clock (bit 17)
    set_bit(RCC->APB1ENR, 17)

    // Set PA2 (pin 2 of GPIOA) to Alternate Function Mode (MODER[5:4] = 10)
    clear_bits(GPIOA->MODER, 0b11 << (2 * 2))
    set_bits(GPIOA->MODER, 0b10 << (2 * 2))

    // Set Alternate Function 7 (USART2) to PA2 in AFRL (AFR[0])
    set_bits(GPIOA->AFR[0], 0b0111 << (4 * 2))

    // Set baud rate to 9600 (assuming 16MHz system clock)
    USART2->BRR = 16000000 / 9600

    // Enable USART2 transmitter (TE) and USART enable (UE) in CR1
    set_bits(USART2->CR1, TE | UE)
```

```c
function uart_send_char(char c):
    // Wait until Transmit Data Register is empty (TXE = 1)
    while not (USART2->SR & TXE):
        continue

    // Write the character into the data register
    USART2->DR = c
```

```c
function uart_send_string(string):
    for each character c in string:
        uart_send_char(c)
```

---

## main.c (Pseudo Code)

```c
function main():
    call uart_init()

    loop forever:
        call uart_send_char('U')  // 0x55
        delay()  // crude delay using empty loop
        call uart_send_char('A')  // 0x41
        delay()
```

---

## Logic Analyzer Setup

- Trigger on falling edge (start bit)
- Set baud rate to **9600**
- Protocol decoder: UART 8N1

Expected pattern:
```
U A U A U A ...
