#include "uart.h"

int main(void) {
    uart_init();
    uart_puts("\r\nDINO bring-up rig (skeleton)\r\n");
    char line[64];
    for (;;) {
        uart_puts("> ");
        uart_getline(line, sizeof line);
        uart_puts("echo: ");
        uart_puts(line);
        uart_puts("\r\n");
    }
}
