#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>

#ifndef CLOCK_FREQ
#define CLOCK_FREQ 1000000  // Default 1MHz if not specified
#endif

// Calculate timer parameters based on desired frequency
// Using Timer1 (16-bit) for better precision
// Timer1 can generate frequencies from ~0.24Hz to 8MHz at 16MHz CPU clock

// For toggle mode, maximum output frequency is F_CPU/2
// But practically limited to F_CPU/4 for clean square wave
#if CLOCK_FREQ > (F_CPU / 2)
#error "Clock frequency too high. Maximum is F_CPU/2 (8MHz with 16MHz CPU clock)"
#endif

#if CLOCK_FREQ < 1
#error "Clock frequency too low. Minimum is 1Hz"
#endif

// Calculate optimal prescaler and compare value
#if CLOCK_FREQ >= 250000
    // No prescaler for high frequencies
    #define PRESCALER 1
    #define TCCR1B_VALUE ((1 << WGM12) | (1 << CS10))
#elif CLOCK_FREQ >= 31250
    // Prescaler 8
    #define PRESCALER 8
    #define TCCR1B_VALUE ((1 << WGM12) | (1 << CS11))
#elif CLOCK_FREQ >= 3900
    // Prescaler 64
    #define PRESCALER 64
    #define TCCR1B_VALUE ((1 << WGM12) | (1 << CS11) | (1 << CS10))
#elif CLOCK_FREQ >= 16
    // Prescaler 256
    #define PRESCALER 256
    #define TCCR1B_VALUE ((1 << WGM12) | (1 << CS12))
#else
    // Prescaler 1024
    #define PRESCALER 1024
    #define TCCR1B_VALUE ((1 << WGM12) | (1 << CS12) | (1 << CS10))
#endif

// Calculate compare value for desired frequency
// Formula: OCR1A = (F_CPU / (2 * prescaler * f_desired)) - 1
// The 2 is because we toggle on each compare match
#define COMPARE_VALUE ((F_CPU / (2UL * PRESCALER * CLOCK_FREQ)) - 1)

#if COMPARE_VALUE > 65535
#error "Clock frequency too low for selected prescaler"
#endif

// Clock output pin (using OC1A on PB1, Arduino D9)
#define CLOCK_PIN PB1
#define CLOCK_DDR DDRB
#define CLOCK_PORT PORTB

// Alternative manual toggle pin (PD4, Arduino D4) for testing
#define MANUAL_CLOCK_PIN PD4
#define MANUAL_CLOCK_DDR DDRD
#define MANUAL_CLOCK_PORT PORTD
#define MANUAL_CLOCK_PIN_REG PIND

// Clean clock output pin (PD5, Arduino D5) with slew rate control
#define CLEAN_CLOCK_PIN PD5
#define CLEAN_CLOCK_DDR DDRD
#define CLEAN_CLOCK_PORT PORTD

// Status LED pin (PB5, Arduino D13)
#define LED_PIN PB5
#define LED_DDR DDRB
#define LED_PORT PORTB

volatile uint32_t clock_cycle_count = 0;
volatile uint8_t clean_clock_state = 0;

// Enable slew rate limiting to reduce ringing
// This adds a small RC delay but cleans up edges
void enable_slew_rate_limit(void) {
    // Method 1: Use internal pull-up as weak driver
    // This creates a softer edge transition
    CLEAN_CLOCK_PORT &= ~(1 << CLEAN_CLOCK_PIN);  // Start low
    CLEAN_CLOCK_DDR &= ~(1 << CLEAN_CLOCK_PIN);   // Set as input
    CLEAN_CLOCK_PORT |= (1 << CLEAN_CLOCK_PIN);   // Enable pull-up
}

void clock_init(void) {
    // Set clock output pins as outputs
    CLOCK_DDR |= (1 << CLOCK_PIN);
    MANUAL_CLOCK_DDR |= (1 << MANUAL_CLOCK_PIN);
    CLEAN_CLOCK_DDR |= (1 << CLEAN_CLOCK_PIN);
    LED_DDR |= (1 << LED_PIN);
    
    // Start with all clock pins low
    CLOCK_PORT &= ~(1 << CLOCK_PIN);
    MANUAL_CLOCK_PORT &= ~(1 << MANUAL_CLOCK_PIN);
    CLEAN_CLOCK_PORT &= ~(1 << CLEAN_CLOCK_PIN);
    
    // Configure Timer1 for CTC mode with toggle on compare match
    // This will generate a square wave on OC1A (PB1/D9)
    TCCR1A = (1 << COM1A0);  // Toggle OC1A on compare match
    TCCR1B = TCCR1B_VALUE;    // CTC mode, prescaler
    
    // Set compare value for desired frequency
    OCR1A = COMPARE_VALUE;
    
    // Enable Timer1 compare match A interrupt for cycle counting
    TIMSK1 = (1 << OCIE1A);
    
    // Enable global interrupts
    sei();
}

// Interrupt service routine for Timer1 compare match A
ISR(TIMER1_COMPA_vect) {
    // Toggle manual clock pin (for verification)
    MANUAL_CLOCK_PORT ^= (1 << MANUAL_CLOCK_PIN);
    
    // Increment cycle counter
    clock_cycle_count++;
    
    // Toggle LED every 1000 cycles (visual indicator)
    if ((clock_cycle_count % 1000) == 0) {
        LED_PORT ^= (1 << LED_PIN);
    }
}

uint32_t clock_get_cycles(void) {
    uint32_t count;
    cli();  // Disable interrupts for atomic read
    count = clock_cycle_count;
    sei();
    return count;
}

void clock_reset_cycles(void) {
    cli();
    clock_cycle_count = 0;
    sei();
}

// For testing: manual clock step (useful for debugging)
void clock_manual_step(void) {
    MANUAL_CLOCK_PORT ^= (1 << MANUAL_CLOCK_PIN);
    _delay_us(1);
    MANUAL_CLOCK_PORT ^= (1 << MANUAL_CLOCK_PIN);
    _delay_us(1);
}

#ifdef STANDALONE_CLOCK
// Standalone test program
int main(void) {
    // Initialize clock generator
    clock_init();
    
    // Print configuration info via UART (if needed)
    // UART init code would go here
    
    // Main loop - clock runs via timer interrupt
    while (1) {
        // Clock is generated automatically by Timer1
        // Could add UART reporting of cycle count here
        _delay_ms(1000);
    }
    
    return 0;
}
#endif