#include <avr/io.h>
#include <util/delay.h>

#define BUZZER_PIN PC0   // A0 is PC0 on ATmega328P
#define BUTTON1_PIN PD2  // Pin 2 is PD2 on ATmega328P
#define BUTTON2_PIN PD3  // Pin 3 is PD3 on ATmega328P
#define BUTTON3_PIN PD4  // Pin 4 is PD4 on ATmega328P

// Generate a tone using software bit-banging with busy-wait
// The delay must use a busy loop since AVR _delay_us requires compile-time constants
void tone(uint16_t frequency, uint16_t duration_ms) {
    uint32_t period_cycles = F_CPU / frequency;  // CPU cycles per period
    uint32_t half_period = period_cycles / 2;     // Cycles for half period
    uint32_t num_toggles = (uint32_t)frequency * duration_ms / 500;  // Total toggles needed

    for (uint32_t i = 0; i < num_toggles; i++) {
        PORTC ^= (1 << BUZZER_PIN);  // Toggle pin

        // Busy-wait for half period
        // Each iteration takes roughly 4 cycles (load, compare, branch, decrement)
        for (uint32_t cycles = half_period / 4; cycles > 0; cycles--) {
            __asm__ __volatile__("nop");
        }
    }
}

// Song: Mario theme (main melody)
void song_scale(void) {
    // Main theme: E E _ E _ C E _ G _ _ _ G4
    tone(659, 100);   // E5
    tone(659, 100);   // E5
    _delay_ms(100);
    tone(659, 100);   // E5
    _delay_ms(100);
    tone(523, 100);   // C5
    tone(659, 100);   // E5
    _delay_ms(100);
    tone(784, 100);   // G5
    _delay_ms(250);
    tone(392, 100);   // G4
    _delay_ms(200);

    // Second part: C G _ E _ A B A# A
    tone(523, 100);   // C5
    _delay_ms(100);
    tone(392, 100);   // G4
    _delay_ms(150);
    tone(330, 100);   // E4
    _delay_ms(100);
    tone(440, 100);   // A4
    _delay_ms(100);
    tone(494, 100);   // B4
    _delay_ms(100);
    tone(466, 100);   // A#4
    tone(440, 100);   // A4
    _delay_ms(100);

    // Third part: G E G A _ F G _ E _ C D B
    tone(392, 120);   // G4
    tone(659, 120);   // E5
    tone(784, 120);   // G5
    tone(880, 100);   // A5
    _delay_ms(100);
    tone(698, 100);   // F5
    tone(784, 100);   // G5
    _delay_ms(100);
    tone(659, 100);   // E5
    _delay_ms(100);
    tone(523, 100);   // C5
    tone(587, 100);   // D5
    tone(494, 100);   // B4
}

// Song: Hedwig's Theme (Harry Potter)
void song_hedwig(void) {
    // Opening phrase: B - E - G - F# - E - B - A - F#
    tone(494, 120);   // B4
    tone(659, 350);   // E5
    tone(784, 160);   // G5
    tone(740, 120);   // F#5

    tone(659, 350);   // E5
    tone(988, 200);   // B5
    tone(880, 550);   // A5 (longer, held note)
    tone(740, 450);   // F#5 (held)
    _delay_ms(80);

    // Second phrase: E - G - F# - D# - F - B
    tone(659, 350);   // E5
    tone(784, 160);   // G5
    tone(740, 120);   // F#5

    tone(622, 350);   // D#5
    tone(698, 200);   // F5
    tone(494, 550);   // B4 (held)
}

// Song: Für Elise (Beethoven)
void song_fur_elise(void) {
    // Opening phrase: E - D# - E - D# - E - B - D - C - A
    tone(659, 150);   // E5
    tone(622, 150);   // D#5
    tone(659, 150);   // E5
    tone(622, 150);   // D#5
    tone(659, 150);   // E5
    tone(494, 150);   // B4
    tone(587, 150);   // D5
    tone(523, 150);   // C5
    tone(440, 300);   // A4
    _delay_ms(150);

    // Second phrase: C - E - A - B
    tone(262, 150);   // C4
    tone(330, 150);   // E4
    tone(440, 150);   // A4
    tone(494, 300);   // B4
    _delay_ms(150);

    // Third phrase: E - G# - B - C
    tone(330, 150);   // E4
    tone(415, 150);   // G#4
    tone(494, 150);   // B4
    tone(523, 300);   // C5
    _delay_ms(150);

    // Fourth phrase: E - E - D# - E - D# - E - B - D - C - A
    tone(330, 150);   // E4
    tone(659, 150);   // E5
    tone(622, 150);   // D#5
    tone(659, 150);   // E5
    tone(622, 150);   // D#5
    tone(659, 150);   // E5
    tone(494, 150);   // B4
    tone(587, 150);   // D5
    tone(523, 150);   // C5
    tone(440, 300);   // A4
}

int main(void) {
    // Set buzzer pin as output
    DDRC |= (1 << BUZZER_PIN);

    // Set button pins as inputs
    DDRD &= ~(1 << BUTTON1_PIN);
    DDRD &= ~(1 << BUTTON2_PIN);
    DDRD &= ~(1 << BUTTON3_PIN);

    // Enable pull-up resistors on button pins
    PORTD |= (1 << BUTTON1_PIN);
    PORTD |= (1 << BUTTON2_PIN);
    PORTD |= (1 << BUTTON3_PIN);

    // Initial state: buzzer low
    PORTC &= ~(1 << BUZZER_PIN);

    // Button 1 state tracking for debouncing
    uint8_t button1_state = 1;
    uint8_t button1_last_reading = 1;
    uint8_t button1_debounce_counter = 0;

    // Button 2 state tracking for debouncing
    uint8_t button2_state = 1;
    uint8_t button2_last_reading = 1;
    uint8_t button2_debounce_counter = 0;

    // Button 3 state tracking for debouncing
    uint8_t button3_state = 1;
    uint8_t button3_last_reading = 1;
    uint8_t button3_debounce_counter = 0;

    const uint8_t DEBOUNCE_THRESHOLD = 5;

    while(1) {
        // Read current button states (0 = pressed, 1 = not pressed)
        uint8_t reading1 = (PIND & (1 << BUTTON1_PIN)) ? 1 : 0;
        uint8_t reading2 = (PIND & (1 << BUTTON2_PIN)) ? 1 : 0;
        uint8_t reading3 = (PIND & (1 << BUTTON3_PIN)) ? 1 : 0;

        // Handle Button 1
        if (reading1 == button1_last_reading) {
            if (button1_debounce_counter < DEBOUNCE_THRESHOLD) {
                button1_debounce_counter++;
            }

            if (button1_debounce_counter == DEBOUNCE_THRESHOLD) {
                if (button1_state == 1 && reading1 == 0) {
                    song_scale();
                }
                button1_state = reading1;
            }
        } else {
            button1_debounce_counter = 0;
            button1_last_reading = reading1;
        }

        // Handle Button 2
        if (reading2 == button2_last_reading) {
            if (button2_debounce_counter < DEBOUNCE_THRESHOLD) {
                button2_debounce_counter++;
            }

            if (button2_debounce_counter == DEBOUNCE_THRESHOLD) {
                if (button2_state == 1 && reading2 == 0) {
                    song_hedwig();
                }
                button2_state = reading2;
            }
        } else {
            button2_debounce_counter = 0;
            button2_last_reading = reading2;
        }

        // Handle Button 3
        if (reading3 == button3_last_reading) {
            if (button3_debounce_counter < DEBOUNCE_THRESHOLD) {
                button3_debounce_counter++;
            }

            if (button3_debounce_counter == DEBOUNCE_THRESHOLD) {
                if (button3_state == 1 && reading3 == 0) {
                    song_fur_elise();
                }
                button3_state = reading3;
            }
        } else {
            button3_debounce_counter = 0;
            button3_last_reading = reading3;
        }

        // Small delay between readings
        _delay_ms(1);
    }

    return 0;
}
