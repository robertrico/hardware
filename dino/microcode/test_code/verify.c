/**
 * verify.c - Verifies specific addresses in eeprom1.bin and eeprom2.bin
 *
 * This program reads eeprom1.bin and eeprom2.bin, then prints the values at key addresses:
 *   - 0x0000, 0x0001, 0x0002, 0x0003, 0x0DED, 0x0FED
 *
 * Output format:
 *   EEPROM1[0xADDR] = 0xXX
 *   EEPROM2[0xADDR] = 0xXX
 *
 * Usage:
 *   gcc verify.c -o verify
 *   ./verify
 */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define EEPROM_SIZE 0x2000

int main(void) {
    const char *fname1 = "eeprom1.bin";
    const char *fname2 = "eeprom2.bin";
    FILE *f1 = fopen(fname1, "rb");
    FILE *f2 = fopen(fname2, "rb");
    if (!f1 || !f2) {
        perror("Failed to open one of the EEPROM files");
        if (f1) fclose(f1);
        if (f2) fclose(f2);
        return 1;
    }
    uint8_t eeprom1[EEPROM_SIZE];
    uint8_t eeprom2[EEPROM_SIZE];
    if (fread(eeprom1, 1, EEPROM_SIZE, f1) != EEPROM_SIZE) {
        fprintf(stderr, "Error reading %s\n", fname1);
        fclose(f1); fclose(f2);
        return 2;
    }
    if (fread(eeprom2, 1, EEPROM_SIZE, f2) != EEPROM_SIZE) {
        fprintf(stderr, "Error reading %s\n", fname2);
        fclose(f1); fclose(f2);
        return 3;
    }
    fclose(f1);
    fclose(f2);

    uint16_t addresses[] = {0x0000, 0x0001, 0x0002, 0x0003, 0x0DED, 0x0FED};
    size_t n = sizeof(addresses)/sizeof(addresses[0]);
    printf("EEPROM Verification Results:\n");
    for (size_t i = 0; i < n; ++i) {
        printf("EEPROM1[0x%04X] = 0x%02X\n", addresses[i], eeprom1[addresses[i]]);
        printf("EEPROM2[0x%04X] = 0x%02X\n", addresses[i], eeprom2[addresses[i]]);
    }
    return 0;
}
