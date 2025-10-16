#include <avr/io.h>
#include <util/delay.h>
#include <stdint.h>
#include <avr/pgmspace.h>

// DAC80 Pin Assignments (ATmega2560)
// 12-bit parallel output to DAC80 inputs
// Bit 1 (MSB) = PA0 (Pin 22)
// Bit 2       = PA1 (Pin 23)
// Bit 3       = PA2 (Pin 24)
// Bit 4       = PA3 (Pin 25)
// Bit 5       = PA4 (Pin 26)
// Bit 6       = PA5 (Pin 27)
// Bit 7       = PA6 (Pin 28)
// Bit 8       = PA7 (Pin 29)
// Bit 9       = PC0 (Pin 37)
// Bit 10      = PC1 (Pin 36)
// Bit 11      = PC2 (Pin 35)
// Bit 12 (LSB)= PC3 (Pin 34)

// Simple sine wave lookup table (64 samples for speed)
const uint16_t sine_table[64] PROGMEM = {
    2048, 2248, 2447, 2642, 2831, 3013, 3185, 3346,
    3495, 3629, 3748, 3850, 3935, 4002, 4050, 4076,
    4091, 4076, 4050, 4002, 3935, 3850, 3748, 3629,
    3495, 3346, 3185, 3013, 2831, 2642, 2447, 2248,
    2048, 1848, 1649, 1454, 1265, 1083, 911, 750,
    601, 467, 348, 246, 161, 94, 46, 20,
    5, 20, 46, 94, 161, 246, 348, 467,
    601, 750, 911, 1083, 1265, 1454, 1649, 1848
};

// 8-bit bit reversal lookup table
const uint8_t bit_reverse[256] PROGMEM = {
    0x00, 0x80, 0x40, 0xC0, 0x20, 0xA0, 0x60, 0xE0, 0x10, 0x90, 0x50, 0xD0, 0x30, 0xB0, 0x70, 0xF0,
    0x08, 0x88, 0x48, 0xC8, 0x28, 0xA8, 0x68, 0xE8, 0x18, 0x98, 0x58, 0xD8, 0x38, 0xB8, 0x78, 0xF8,
    0x04, 0x84, 0x44, 0xC4, 0x24, 0xA4, 0x64, 0xE4, 0x14, 0x94, 0x54, 0xD4, 0x34, 0xB4, 0x74, 0xF4,
    0x0C, 0x8C, 0x4C, 0xCC, 0x2C, 0xAC, 0x6C, 0xEC, 0x1C, 0x9C, 0x5C, 0xDC, 0x3C, 0xBC, 0x7C, 0xFC,
    0x02, 0x82, 0x42, 0xC2, 0x22, 0xA2, 0x62, 0xE2, 0x12, 0x92, 0x52, 0xD2, 0x32, 0xB2, 0x72, 0xF2,
    0x0A, 0x8A, 0x4A, 0xCA, 0x2A, 0xAA, 0x6A, 0xEA, 0x1A, 0x9A, 0x5A, 0xDA, 0x3A, 0xBA, 0x7A, 0xFA,
    0x06, 0x86, 0x46, 0xC6, 0x26, 0xA6, 0x66, 0xE6, 0x16, 0x96, 0x56, 0xD6, 0x36, 0xB6, 0x76, 0xF6,
    0x0E, 0x8E, 0x4E, 0xCE, 0x2E, 0xAE, 0x6E, 0xEE, 0x1E, 0x9E, 0x5E, 0xDE, 0x3E, 0xBE, 0x7E, 0xFE,
    0x01, 0x81, 0x41, 0xC1, 0x21, 0xA1, 0x61, 0xE1, 0x11, 0x91, 0x51, 0xD1, 0x31, 0xB1, 0x71, 0xF1,
    0x09, 0x89, 0x49, 0xC9, 0x29, 0xA9, 0x69, 0xE9, 0x19, 0x99, 0x59, 0xD9, 0x39, 0xB9, 0x79, 0xF9,
    0x05, 0x85, 0x45, 0xC5, 0x25, 0xA5, 0x65, 0xE5, 0x15, 0x95, 0x55, 0xD5, 0x35, 0xB5, 0x75, 0xF5,
    0x0D, 0x8D, 0x4D, 0xCD, 0x2D, 0xAD, 0x6D, 0xED, 0x1D, 0x9D, 0x5D, 0xDD, 0x3D, 0xBD, 0x7D, 0xFD,
    0x03, 0x83, 0x43, 0xC3, 0x23, 0xA3, 0x63, 0xE3, 0x13, 0x93, 0x53, 0xD3, 0x33, 0xB3, 0x73, 0xF3,
    0x0B, 0x8B, 0x4B, 0xCB, 0x2B, 0xAB, 0x6B, 0xEB, 0x1B, 0x9B, 0x5B, 0xDB, 0x3B, 0xBB, 0x7B, 0xFB,
    0x07, 0x87, 0x47, 0xC7, 0x27, 0xA7, 0x67, 0xE7, 0x17, 0x97, 0x57, 0xD7, 0x37, 0xB7, 0x77, 0xF7,
    0x0F, 0x8F, 0x4F, 0xCF, 0x2F, 0xAF, 0x6F, 0xEF, 0x1F, 0x9F, 0x5F, 0xDF, 0x3F, 0xBF, 0x7F, 0xFF
};

// 4-bit bit reversal lookup table
const uint8_t bit_reverse_4[16] PROGMEM = {
    0x0, 0x8, 0x4, 0xC, 0x2, 0xA, 0x6, 0xE, 0x1, 0x9, 0x5, 0xD, 0x3, 0xB, 0x7, 0xF
};

// Write 12-bit value to DAC80 - optimized for speed
void dac_write(uint16_t value) {
    uint8_t upper = pgm_read_byte(&bit_reverse[(value >> 4) & 0xFF]);
    uint8_t lower = pgm_read_byte(&bit_reverse_4[value & 0x0F]);

    // Write both ports as quickly as possible (back-to-back writes)
    PORTA = upper;
    PORTC = lower;  // Assume PORTC upper bits stay constant
}

// Musical notes (delay in microseconds for each sample)
// Formula: delay = (1000000 / frequency) / 64 samples
#define NOTE_C4  238  // 262 Hz (Middle C)
#define NOTE_D4  212  // 294 Hz
#define NOTE_E4  189  // 330 Hz
#define NOTE_F4  178  // 349 Hz
#define NOTE_G4  159  // 392 Hz
#define NOTE_A4  142  // 440 Hz (Concert A)
#define NOTE_B4  126  // 494 Hz
#define NOTE_C5  119  // 523 Hz (High C)
#define REST     0    // Silence

// Note durations (in milliseconds)
#define QUARTER  400
#define HALF     800
#define WHOLE    1600

// Twinkle Twinkle Little Star
// Notes: C C G G A A G - F F E E D D C
const uint8_t melody[] PROGMEM = {
    NOTE_C4, NOTE_C4, NOTE_G4, NOTE_G4, NOTE_A4, NOTE_A4, NOTE_G4, REST,
    NOTE_F4, NOTE_F4, NOTE_E4, NOTE_E4, NOTE_D4, NOTE_D4, NOTE_C4, REST,
    NOTE_G4, NOTE_G4, NOTE_F4, NOTE_F4, NOTE_E4, NOTE_E4, NOTE_D4, REST,
    NOTE_G4, NOTE_G4, NOTE_F4, NOTE_F4, NOTE_E4, NOTE_E4, NOTE_D4, REST,
    NOTE_C4, NOTE_C4, NOTE_G4, NOTE_G4, NOTE_A4, NOTE_A4, NOTE_G4, REST,
    NOTE_F4, NOTE_F4, NOTE_E4, NOTE_E4, NOTE_D4, NOTE_D4, NOTE_C4, REST
};

const uint16_t duration[] PROGMEM = {
    QUARTER, QUARTER, QUARTER, QUARTER, QUARTER, QUARTER, HALF, QUARTER,
    QUARTER, QUARTER, QUARTER, QUARTER, QUARTER, QUARTER, HALF, QUARTER,
    QUARTER, QUARTER, QUARTER, QUARTER, QUARTER, QUARTER, HALF, QUARTER,
    QUARTER, QUARTER, QUARTER, QUARTER, QUARTER, QUARTER, HALF, QUARTER,
    QUARTER, QUARTER, QUARTER, QUARTER, QUARTER, QUARTER, HALF, QUARTER,
    QUARTER, QUARTER, QUARTER, QUARTER, QUARTER, QUARTER, HALF, QUARTER
};

// Play a single note
void play_note(uint8_t note_delay, uint16_t note_duration) {
    if (note_delay == REST) {
        // Silence - output mid-scale
        dac_write(2048);
        // Manual delay for rest
        for (volatile uint32_t ms = 0; ms < note_duration; ms++) {
            _delay_ms(1);
        }
        return;
    }

    uint32_t cycles = (uint32_t)note_duration * 1000 / (note_delay * 64);

    for (uint32_t c = 0; c < cycles; c++) {
        for (uint8_t i = 0; i < 64; i++) {
            dac_write(pgm_read_word(&sine_table[i]));
            // Manual delay loop instead of _delay_us()
            for (volatile uint16_t d = 0; d < note_delay * 4; d++) {
                __asm__ __volatile__ ("nop");
            }
        }
    }
}

int main(void) {
    // Configure PORTA (8 MSBs: Bit 1-8) as outputs
    DDRA = 0xFF;

    // Configure PORTC lower 4 bits (4 LSBs: Bit 9-12) as outputs
    DDRC |= 0x0F;

    // Clear PORTC upper bits so we can write full bytes
    PORTC = 0x00;

    // Initialize DAC to mid-scale (bipolar zero)
    dac_write(2048);

    _delay_ms(1000);  // Initial delay

    while(1) {
        // Play the melody
        for (uint8_t i = 0; i < sizeof(melody); i++) {
            uint8_t note = pgm_read_byte(&melody[i]);
            uint16_t dur = pgm_read_word(&duration[i]);
            play_note(note, dur);
            _delay_ms(50);  // Small gap between notes
        }

        // Long pause before repeating
        _delay_ms(2000);
    }

    return 0;
}
