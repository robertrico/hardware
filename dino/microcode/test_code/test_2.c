/**
 * test_2.c - Program ROM test data generator for DINO
 *
 * This program generates a single binary file (rom.bin) for a program ROM.
 * It writes specific values at 4 different addresses for testing purposes.
 * All other bytes are zero-filled.
 *
 * Addresses and values written:
 *   - 0x0000: 0xAA
 *   - 0x0100: 0x55
 *   - 0x0ABC: 0x77
 *   - 0x0FFF: 0x99
 *
 * Usage:
 *   gcc test_2.c -o test_2
 *   ./test_2
 *   hexdump -C rom.bin
 */
#include <stdio.h>
#include <stdint.h>

#define ROM_SIZE 0x8000  // 32K

int main(void) {
    FILE *f = fopen("rom.bin", "wb");
    if (!f) {
        perror("Failed to open rom.bin for writing");
        return 1;
    }
    uint8_t rom[ROM_SIZE] = {0};
    // Write test values at 4 addresses (all within first 4K for legacy check)
    rom[0x0000] = 0xAA;   // 0x0000: 0xAA (1010 1010)
    rom[0x0100] = 0x55;   // 0x0100: 0x55 (0101 0101)
    rom[0x0ABC] = 0x77;   // 0x0ABC: 0x77 (0111 0111)
    rom[0x0FFF] = 0x99;   // 0x0FFF: 0x99 (1001 1001)
    fwrite(rom, sizeof(uint8_t), ROM_SIZE, f);
    fclose(f);
    return 0;
}
