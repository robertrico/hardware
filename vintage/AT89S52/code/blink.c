/**
 * AT89S52 Multi-Function Demo Program
 *
 * This program demonstrates multiple I/O operations:
 * - P1.0: Fast blinking LED (~1 kHz)
 * - P1.1: LED toggled by switch on P2.0
 * - P1.2: Slow blinking LED (~1 Hz)
 * - P2.0: Switch input (pull high to toggle P1.1 LED)
 * - P3.0/P3.1: UART communication at 9600 baud
 *
 * AT89S52 runs with 11.0592 MHz external crystal (standard for UART)
 *
 * Connections:
 * - LED1 anode -> P1.0 (through 220-330Ω resistor) - Fast blink
 * - LED2 anode -> P1.1 (through 220-330Ω resistor) - Switch controlled
 * - LED3 anode -> P1.2 (through 220-330Ω resistor) - Slow blink
 * - LED cathodes -> GND
 * - Switch -> P2.0 (with pull-down resistor, press connects to VCC)
 * - P3.0 (RXD) -> FT232 TXD
 * - P3.1 (TXD) -> FT232 RXD
 *
 * Serial Settings: 9600 baud, 8N1
 */

#include <8051.h>

// LEDs
#define LED_FAST    P1_0  // Fast blinking LED
#define LED_SWITCH  P1_1  // Switch-controlled LED
#define LED_SLOW    P1_2  // Slow blinking LED

// Switch input
#define SWITCH      P2_0

// UART configuration with 11.0592 MHz crystal (perfect for UART!)
// Formula: Baud = Crystal / (384 * (256 - TH1))
// For 9600: TH1 = 256 - (11059200 / (384 * 9600)) = 256 - 3 = 253
// Actual: 11059200 / (384 * 3) = 9600 baud EXACTLY!
#define TH1_VALUE 0xFD  // Perfect 9600 baud with 11.0592 MHz

// Very short delay function for kHz range blinking
void delay_us(unsigned char us) {
    unsigned char i;
    // At 11.0592 MHz: instruction cycle = 11.0592MHz / 12 = 921.6 kHz
    // Each iteration takes ~12 machine cycles
    for (i = 0; i < us; i++) {
        __asm nop __endasm;
    }
}

// UART initialization
void uart_init(void) {
    TMOD &= 0x0F;      // Clear Timer 1 mode bits
    TMOD |= 0x20;      // Timer 1 mode 2: 8-bit auto-reload
    TH1 = TH1_VALUE;   // Set baud rate
    TL1 = TH1_VALUE;   // Initialize timer
    TR1 = 1;           // Start Timer 1
    SCON = 0x50;       // UART mode 1: 8-bit, enable RX
    TI = 1;            // Ready to transmit
}

// Send character via UART
void putchar(char c) {
    while (!TI);       // Wait until ready
    TI = 0;            // Clear flag
    SBUF = c;          // Send character
}

// Send string via UART
void uart_print(const char *str) {
    while (*str) {
        putchar(*str++);
    }
}

// Send string with newline
void uart_println(const char *str) {
    uart_print(str);
    putchar('\r');
    putchar('\n');
}

// Receive character via UART (non-blocking)
// Returns 1 if character received, 0 if not
unsigned char getchar_nb(char *c) {
    if (RI) {              // If character received
        RI = 0;            // Clear receive flag
        *c = SBUF;         // Read character
        return 1;          // Character available
    }
    return 0;              // No character
}

void main(void) {
    unsigned int slow_counter = 0;
    unsigned int slow_period = 1000;  // Toggle LED_SLOW every 1000 fast cycles (~1 Hz)
    unsigned int uart_counter = 0;
    unsigned int uart_period = 5000;  // Send UART message every ~5 seconds
    unsigned char switch_prev = 0;    // Previous switch state for edge detection
    char rx_char;                     // Received UART character

    // Initialize UART
    uart_init();

    // Send startup banner
    uart_println("=============================");
    uart_println("AT89S52 Demo Program");
    uart_println("Clock: 11.0592 MHz");
    uart_println("Baud: 9600");
    uart_println("Commands: 't' = toggle SWITCH LED");
    uart_println("=============================");

    // Main loop
    while (1) {
        // Toggle LED_FAST at kHz rate
        LED_FAST = 1;
        delay_us(50);
        LED_FAST = 0;
        delay_us(50);

        // Toggle LED_SLOW at human-visible rate (~1 Hz)
        slow_counter++;
        if (slow_counter >= slow_period) {
            LED_SLOW = !LED_SLOW;
            slow_counter = 0;
        }

        // Check switch on P2.0 - toggle LED_SWITCH on rising edge
        if (SWITCH == 1 && switch_prev == 0) {
            // Rising edge detected - toggle LED
            LED_SWITCH = !LED_SWITCH;
            uart_println("Switch pressed!");
        }
        switch_prev = SWITCH;  // Remember current state

        // Check for UART commands
        if (getchar_nb(&rx_char)) {
            if (rx_char == 't' || rx_char == 'T') {
                LED_SWITCH = !LED_SWITCH;
                uart_print("LED_SWITCH toggled via UART: ");
                uart_println(LED_SWITCH ? "ON" : "OFF");
            }
        }

        // Send periodic UART status
        uart_counter++;
        if (uart_counter >= uart_period) {
            uart_print("Status: P1.0=");
            putchar(LED_FAST ? '1' : '0');
            uart_print(" P1.1=");
            putchar(LED_SWITCH ? '1' : '0');
            uart_print(" P1.2=");
            putchar(LED_SLOW ? '1' : '0');
            uart_print(" SW=");
            uart_println(SWITCH ? "HIGH" : "LOW");
            uart_counter = 0;
        }
    }
}
