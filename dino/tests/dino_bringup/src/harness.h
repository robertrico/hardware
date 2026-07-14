#ifndef HARNESS_H
#define HARNESS_H
#include <stdbool.h>
#include <stdint.h>

typedef struct { volatile uint8_t *port, *ddr, *pinr; uint8_t bit; } hwpin_t;

bool pin_lookup(const char *megapin, hwpin_t *out);
void drv(const hwpin_t *p, bool level);
void rel(const hwpin_t *p);
bool smp(const hwpin_t *p);
bool floats(const hwpin_t *p);
void settle(void);
void clk_bind(const hwpin_t *clk, const hwpin_t *clkn);
void clk_lo(void);
void clk_hi(void);
void step(void);

void bus_w_write(uint8_t v);
uint8_t bus_w_read(void);
void bus_w_release(void);
void bus_mdr_write(uint8_t v);
uint8_t bus_mdr_read(void);
void bus_mdr_release(void);
uint16_t bus_m_read(void);
void bus_m_drive(uint16_t v);
void bus_m_release(void);

void test_begin(const char *module, const char *name);
void test_check_u16(uint16_t got, uint16_t want, const char *label);
void test_check_bool(bool got, bool want, const char *label);
bool test_end(void);
extern uint16_t g_pass, g_fail;

#endif
