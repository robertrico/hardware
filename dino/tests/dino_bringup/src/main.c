#include "uart.h"
#include "shell.h"

int main(void) {
    uart_init();
    uart_puts("\r\nDINO bring-up rig — 'help' for commands\r\n");
    char line[64];
    for (;;) {
        uart_puts("> ");
        uart_getline(line, sizeof line);
        cmd_t c = shell_parse(line);
        shell_execute(&c);
    }
}
