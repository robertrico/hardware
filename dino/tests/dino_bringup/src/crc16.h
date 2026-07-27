#ifndef CRC16_H
#define CRC16_H
#include <stdint.h>

/* CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF) — the algorithm
   microcode_gen.py prints per-chip. Rig and generator must agree;
   hosttest/test_crc16.c enforces it. */
#define CRC16_INIT 0xFFFF
uint16_t crc16_update(uint16_t crc, uint8_t byte);

#endif
