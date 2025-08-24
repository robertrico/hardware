#include <avr/io.h>
#include <util/delay.h>

// Test selection - define at compile time with -DTEST_TYPE=xxx
#ifdef TEST_373
    #include "test_373.h"
#endif

#ifdef TEST_245_373
    #include "test_245_373.h"
#endif

#ifdef TEST_IR
    #include "test_ir.h"
#endif

#ifdef TEST_REGISTER
    #include "test_register.h"
#endif

// Add more test includes here as needed
// #ifdef TEST_245
//     #include "test_245.h"
// #endif

int main(void) {
    // Route to appropriate test based on compile flag
    #ifdef TEST_373
        test_373_run();
    #elif defined(TEST_245_373)
        test_245_373_run();
    #elif defined(TEST_IR)
        test_ir_run();
    #elif defined(TEST_REGISTER)
        test_register_run();
    #elif defined(TEST_245)
        // test_245_run();
    #else
        // Default: blink red LED on D0 to show no test selected
        DDRD |= (1 << PD0);  // D0 (red LED) as output
        while (1) {
            PORTD ^= (1 << PD0);
            _delay_ms(1000);
        }
    #endif
    
    return 0;
}