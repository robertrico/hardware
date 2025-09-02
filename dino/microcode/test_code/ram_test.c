// RAM Test ROM for AT28C64 EEPROM
// [7]   = PULSE_REQ
// [6]   = RAM_LOAD (write to SRAM)
// [5]   = RAM_OUT (read from SRAM)
// [4:0] = DATA (lower 5 bits, upper 3 bits wired to GND on hardware)
//
// Test pattern: Write, then Read for DMM verification
// PULSE_REQ and RAM_LOAD always together for writes
// Never PULSE_REQ+RAM_LOAD on consecutive addresses (for ~WE edge)
// gcc -o ram_test ram_test.c

#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define ROM_SIZE 8192        // AT28C64 is 8K x 8
#define PULSE_REQ (1 << 7)   // 0x80
#define RAM_LOAD  (1 << 6)   // 0x40
#define RAM_OUT   (1 << 5)   // 0x20
#define DATA_MASK 0x1F       // Lower 5 bits for data

int main() {
    uint8_t rom[ROM_SIZE];
    memset(rom, 0, ROM_SIZE);
    
    printf("Write-Read test pairs for DMM verification:\n\n");
    
    // Clear RAM first - write 0x00
    rom[0x0000] = PULSE_REQ | RAM_LOAD | 0x00;  // 0xC0 = 11000000b
    printf("0x%04X: 0x%02X (Clear RAM - Write 0x00)\n", 0x0000, rom[0x0000]);
    
    rom[0x0001] = RAM_OUT;
    printf("0x%04X: 0x%02X (Read - verify 0x00)\n", 0x0001, rom[0x0001]);
    
    // Test 1: Alternating pattern
    rom[0x0002] = PULSE_REQ | RAM_LOAD | 0x15;  // 0xD5 = 11010101b
    printf("0x%04X: 0x%02X (Write 0x15 [10101b])\n", 0x0002, rom[0x0002]);
    
    rom[0x0003] = RAM_OUT;  // Read for verification
    printf("0x%04X: 0x%02X (Read - verify 0x15)\n", 0x0003, rom[0x0003]);
    
    // Test 2: Inverse alternating
    rom[0x0004] = PULSE_REQ | RAM_LOAD | 0x0A;  // 0xCA = 11001010b
    printf("0x%04X: 0x%02X (Write 0x0A [01010b])\n", 0x0004, rom[0x0004]);
    
    rom[0x0005] = RAM_OUT;
    printf("0x%04X: 0x%02X (Read - verify 0x0A)\n", 0x0005, rom[0x0005]);
    
    // Test 3: All ones
    rom[0x0006] = PULSE_REQ | RAM_LOAD | 0x1F;  // 0xDF = 11011111b
    printf("0x%04X: 0x%02X (Write 0x1F [11111b])\n", 0x0006, rom[0x0006]);
    
    rom[0x0007] = RAM_OUT;
    printf("0x%04X: 0x%02X (Read - verify 0x1F)\n", 0x0007, rom[0x0007]);
    
    // Write EEPROM image
    FILE *f = fopen("ram_test.bin", "wb");
    if (f) {
        fwrite(rom, 1, ROM_SIZE, f);
        fclose(f);
        printf("\nEEPROM image written to ram_test.bin (8KB for AT28C64)\n");
        printf("\nTest Summary:\n");
        printf("  - Clear RAM with 0x00 first\n");
        printf("  - Each write followed by read for DMM verification\n");
        printf("  - PULSE_REQ + RAM_LOAD always together for writes\n");
        printf("  - No consecutive PR+RL (preserves ~WE edge)\n");
        printf("  - Test patterns:\n");
        printf("    * 0x00 (clear)\n");
        printf("    * 0x15 (10101b)\n");
        printf("    * 0x0A (01010b)\n");
        printf("    * 0x1F (11111b)\n");
        printf("\nDMM Testing:\n");
        printf("  - After each RAM_OUT, verify data lines D0-D4\n");
        printf("  - D5-D7 should always read 0 (wired to GND)\n");
    } else {
        printf("Error: Could not create ram_test.bin\n");
        return 1;
    }
    
    return 0;
}