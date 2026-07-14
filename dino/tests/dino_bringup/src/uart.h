#ifndef UART_H
#define UART_H
#include <stdint.h>

void uart_init(void);
void uart_putc(char c);
void uart_puts(const char *s);
void uart_puthex8(uint8_t v);
void uart_puthex16(uint16_t v);
void uart_putdec(uint16_t v);
/* Blocking line read with echo. Returns length. Strips CR/LF, NUL-terminates. */
uint8_t uart_getline(char *buf, uint8_t maxlen);

#endif
