/**
 * verify_rom.c - Verifies specific addresses in rom.bin
 *
 * This program reads rom.bin and prints the values at 0x0000, 0x0100, 0x0ABC, and 0x0FFF.
 *
 * Output format:
 *   ROM[0xADDR] = 0xXX (binary)
 *
 * Usage:
 *   gcc verify_rom.c -o verify_rom
 *   ./verify_rom
 */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define ROM_SIZE 0x1000

void print_bin(uint8_t val) {
    for (int i = 7; i >= 0; --i)
        putchar((val & (1 << i)) ? '1' : '0');
}

int main(void) {
    const char *fname = "rom.bin";
    FILE *f = fopen(fname, "rb");
    if (!f) {
        perror("Failed to open rom.bin");
        return 1;
    }
    uint8_t rom[ROM_SIZE];
    if (fread(rom, 1, ROM_SIZE, f) != ROM_SIZE) {
        fprintf(stderr, "Error reading %s\n", fname);
        fclose(f);
        return 2;
    }
    fclose(f);
    uint16_t addresses[] = {0x0000, 0x0100, 0x0ABC, 0x0FFF};
    size_t n = sizeof(addresses)/sizeof(addresses[0]);
    printf("ROM Verification Results:\n");
    for (size_t i = 0; i < n; ++i) {
        uint8_t val = rom[addresses[i]];
        printf("ROM[0x%04X] = 0x%02X (", addresses[i], val);
        print_bin(val);
        printf(")\n");
    }
    return 0;
}
