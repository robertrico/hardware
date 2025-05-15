#ifndef GPIO_H_
#define GPIO_H_

#include "stm32f4xx.h"
#include <stdbool.h>

void led_init(void);
void led_toggle(void);
void led_toggleb(void);
bool get_btn_state(void);

#endif /* GPIO_H_ */