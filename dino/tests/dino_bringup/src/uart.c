#include <avr/io.h>
#include <avr/pgmspace.h>
#include "uart.h"

void uart_init(void) {
    /* 115200 @ 16MHz: U2X=1, UBRR=16 -> 117647 baud, 2.1% error (fine) */
    UCSR0A = _BV(U2X0);
    UBRR0H = 0;
    UBRR0L = 16;
    UCSR0B = _BV(RXEN0) | _BV(TXEN0);
    UCSR0C = _BV(UCSZ01) | _BV(UCSZ00);   /* 8N1 */
}

void uart_putc(char c) {
    loop_until_bit_is_set(UCSR0A, UDRE0);
    UDR0 = (uint8_t)c;
}

void uart_puts(const char *s) {
    while (*s) uart_putc(*s++);
}

void uart_puts_p(const char *s) {
    char c;
    while ((c = (char)pgm_read_byte(s++)) != '\0') uart_putc(c);
}

static char hexdigit(uint8_t n) { return n < 10 ? '0' + n : 'A' + n - 10; }

void uart_puthex8(uint8_t v) {
    uart_putc(hexdigit(v >> 4));
    uart_putc(hexdigit(v & 0x0F));
}

void uart_puthex16(uint16_t v) {
    uart_puthex8((uint8_t)(v >> 8));
    uart_puthex8((uint8_t)v);
}

void uart_putdec(uint16_t v) {
    char buf[6];
    uint8_t i = 0;
    do { buf[i++] = '0' + v % 10; v /= 10; } while (v);
    while (i) uart_putc(buf[--i]);
}

static char uart_getc(void) {
    loop_until_bit_is_set(UCSR0A, RXC0);
    return (char)UDR0;
}

uint8_t uart_getline(char *buf, uint8_t maxlen) {
    uint8_t n = 0;
    for (;;) {
        char c = uart_getc();
        if (c == '\r' || c == '\n') { uart_puts("\r\n"); break; }
        if ((c == 0x08 || c == 0x7F) && n) { n--; uart_puts("\b \b"); continue; }
        if (n + 1 < maxlen && c >= ' ') { buf[n++] = c; uart_putc(c); }
    }
    buf[n] = '\0';
    return n;
}
