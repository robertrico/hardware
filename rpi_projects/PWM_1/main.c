#include "pico/stdlib.h"
#include <stdio.h>
#include "hardware/pwm.h"

#define SLEEPTIME 250

int main()
{
    stdio_init_all();

    printf("Configuring Pins...\n");

    /// \tag::setup_pwm[]

    // Tell GPIO 16 and 17 they are allocated to the PWM
    gpio_set_function(16, GPIO_FUNC_PWM);
    gpio_set_function(17, GPIO_FUNC_PWM);

    // set 18 and 19 to be outputs active low
    gpio_init(18);
    gpio_set_dir(18, GPIO_OUT);
    gpio_init(19);
    gpio_set_dir(19, GPIO_OUT);

    // Set direction: forward
    gpio_put(18, 1);
    gpio_put(19, 0);

    gpio_init(20);
    gpio_set_dir(20, GPIO_OUT);
    gpio_put(20, 1);

    // Find out which PWM slice is connected to GPIO 16
    uint slice_num = pwm_gpio_to_slice_num(16);

    // Set period of 4 cycles (0 to 3 inclusive)
    pwm_set_wrap(slice_num, 12499);
    // Set channel A output high for one cycle before dropping
    pwm_set_chan_level(slice_num, PWM_CHAN_A, 12499 / 2);
    // Set initial B output high for three cycles before dropping
    pwm_set_chan_level(slice_num, PWM_CHAN_B, (12499 * 3) / 4);
    // Set the PWM running
    pwm_set_enabled(slice_num, true);
    /// \end::setup_pwm[]

    // Note we could also use pwm_set_gpio_level(gpio, x) which looks up the
    // correct slice and channel for a given GPIO.

    return 0;
}
