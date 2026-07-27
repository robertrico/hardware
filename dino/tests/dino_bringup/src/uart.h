#ifndef UART_H
#define UART_H
#include <stdint.h>
#include <avr/pgmspace.h>

void uart_init(void);
void uart_putc(char c);
void uart_puts(const char *s);
/* Print a NUL-terminated string stored in flash (PROGMEM address). */
void uart_puts_p(const char *s);
/* Literal-message printer: stores the literal in flash, not .data.
   RAM is the scarce resource on this rig (classic AVR copies every
   plain string literal into .data at boot) — use this for ALL literal
   messages; plain uart_puts() is for runtime pointers (names, labels). */
#define uart_putsP(lit) uart_puts_p(PSTR(lit))
void uart_puthex8(uint8_t v);
void uart_puthex16(uint16_t v);
void uart_putdec(uint16_t v);
/* Blocking line read with echo. Returns length. Strips CR/LF, NUL-terminates. */
uint8_t uart_getline(char *buf, uint8_t maxlen);

#endif
