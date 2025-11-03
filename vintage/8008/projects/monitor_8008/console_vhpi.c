/*
 * Console I/O Functions for GHDL VHPIDIRECT
 * Provides real terminal I/O for Intel 8008 simulation
 */

#include <stdio.h>
#include <stdlib.h>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/select.h>
#include <errno.h>

static struct termios orig_termios;
static int raw_mode_enabled = 0;

/*
 * Restore terminal to original settings
 */
void console_cleanup(void) {
    if (raw_mode_enabled) {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
        raw_mode_enabled = 0;
    }
}

/*
 * Initialize raw mode terminal
 * Disables line buffering and echo for character-by-character input
 */
void console_init(void) {
    if (raw_mode_enabled) return;

    // Get current terminal settings
    tcgetattr(STDIN_FILENO, &orig_termios);

    // Create modified settings for raw mode
    struct termios raw = orig_termios;

    // Keep canonical mode (line buffering) and echo enabled
    // This allows user to type, see what they're typing, and press Enter to submit
    // Keep ICANON enabled for line-at-a-time input
    // Keep ECHO enabled so user can see their typing

    // With ICANON enabled, VMIN/VTIME are not used
    // Input is buffered until newline

    // Apply settings
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
    raw_mode_enabled = 1;

    // Ensure we restore on exit
    atexit(console_cleanup);
}

/*
 * Output a character to the console
 * Called by VHDL when 8008 executes OUT 0
 */
void console_putc(char c) {
    // Initialize on first use
    if (!raw_mode_enabled) {
        console_init();
    }

    // Write character to stdout
    putchar(c);
    fflush(stdout);
}

/*
 * Check if a key is available (non-blocking)
 * Called by VHDL when 8008 executes INP 3 (status port)
 * Returns: 1 if key available, 0 otherwise
 */
int console_kbhit(void) {
    // Initialize on first use
    if (!raw_mode_enabled) {
        console_init();
    }

    // Use select() to check if stdin has data
    struct timeval tv = {0, 0};
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(STDIN_FILENO, &fds);

    return select(STDIN_FILENO + 1, &fds, NULL, NULL, &tv) > 0;
}

/*
 * Read a character from the console (BLOCKING)
 * Called by VHDL when 8008 executes INP 2
 * This will PAUSE the simulation until you press a key!
 */
unsigned char console_getc(void) {
    // Initialize on first use
    if (!raw_mode_enabled) {
        console_init();
    }

    unsigned char c;
    ssize_t result;

    // Block until a character is available
    while (1) {
        result = read(STDIN_FILENO, &c, 1);

        if (result == 1) {
            return c;
        } else if (result == 0) {
            // EOF - wait a bit and try again (stdin might be redirected/closed)
            usleep(100000);  // 100ms
            continue;
        } else if (result < 0) {
            // Error
            if (errno == EINTR) {
                // Interrupted by signal, try again
                continue;
            }
            // Other error, return 0
            return 0;
        }
    }
}

/*
 * Non-blocking read (returns 0 if no key available)
 * Called by VHDL when 8008 executes INP 2 and wants to poll
 */
unsigned char console_getc_nonblock(void) {
    // Initialize on first use
    if (!raw_mode_enabled) {
        console_init();
    }

    if (console_kbhit()) {
        unsigned char c;
        if (read(STDIN_FILENO, &c, 1) == 1) {
            return c;
        }
    }

    return 0;
}
