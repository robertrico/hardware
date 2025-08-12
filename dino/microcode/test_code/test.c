
/**
 * test.c - Parallel EEPROM test data generator for DINO
 *
 * This program generates two binary files (eeprom1.bin and eeprom2.bin)
 * for burning into two parallel EEPROMs used in the DINO hardware project.
 *
 * Each file is 4096 bytes (0x1000) and specific values are written at key addresses:
 *   - eeprom1.bin: 0xDE at 0x0000, 0xBE at 0x0001, 0xBE at 0x0DED, 0xFE at 0x0FED
 *   - eeprom2.bin: 0xAD at 0x0000, 0xEF at 0x0001, 0xEF at 0x0DED, 0xED at 0x0FED
 *
#
# Usage:
#   To compile:
#     gcc test.c -o test
#
#   To generate the EEPROM files:
#     ./test
#
#   To check the contents of each bin file:
#     hexdump -C eeprom1.bin
#     hexdump -C eeprom2.bin
#
#   How to read the output:
#     - The address at the start of each line (e.g., 00000fe0) is the starting offset for that line.
#     - Each line shows 16 bytes, so the first byte is at the line's address, the second at address+1, etc.
#     - To find a specific address (e.g., 0x0FED), calculate its position: 0x0FE0 + 13 = 0x0FED (13th byte in the line).
#     - Count bytes from left to right, starting at 0 for each line.
#     - Example: If you see 'fe' as the 13th byte on the line starting with 00000fe0, that's the value at 0x0FED.
#
 * All other bytes are zero-filled. This is for hardware and microcode testing.
 */
#include <stdio.h>
#include <stdint.h>

int main(void) {
    FILE *f1 = fopen("eeprom1.bin", "wb");
    FILE *f2 = fopen("eeprom2.bin", "wb");
    if (!f1 || !f2) {
        perror("Failed to open one of the files");
        if (f1) fclose(f1);
        if (f2) fclose(f2);
        return 1;
    }
    uint8_t eeprom1[0x2000] = {0};
    uint8_t eeprom2[0x2000] = {0};

    // Fill both EEPROMs with zeros
    for (int i = 0; i < sizeof(eeprom1); i++) {
        eeprom1[i] = 0x00;
        eeprom2[i] = 0x00;
    }

    // Write 0xDE at 0x0000 in eeprom1
    eeprom1[0x0000] = 0xDE;
    // Write 0xAD at 0x0000 in eeprom2
    eeprom2[0x0000] = 0xAD;

    // Write 0xBE at 0x0001 in eeprom1
    eeprom1[0x0001] = 0xBE;
    // Write 0xEF at 0x0001 in eeprom2
    eeprom2[0x0001] = 0xEF;

    // Write 0xBA at 0x0002 in eeprom1
    eeprom1[0x0002] = 0xBA;
    // Write 0xBE at 0x0002 in eeprom2
    eeprom2[0x0002] = 0xBE;

    // Write 0xBE at 0x0DED in eeprom1
    eeprom1[0x0DED] = 0xBE;

    // Write 0xEF at 0x0DED in eeprom2
    eeprom2[0x0DED] = 0xEF;

    // Write 0xCA at 0x0003 in eeprom1
    eeprom1[0x0003] = 0xCA;
    // Write 0xFE at 0x0003 in eeprom2
    eeprom2[0x0003] = 0xFE;

    // Write 0xFE at 0x0FED in eeprom1
    eeprom1[0x0FED] = 0xFE;
    // Write 0xED at 0x0FED in eeprom2
    eeprom2[0x0FED] = 0xED;

    fwrite(eeprom1, sizeof(uint8_t), sizeof(eeprom1), f1);
    fwrite(eeprom2, sizeof(uint8_t), sizeof(eeprom2), f2);
    fclose(f1);
    fclose(f2);
    return 0;
}
