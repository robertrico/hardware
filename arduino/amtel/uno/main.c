#include <avr/io.h>
#include <util/delay.h>

int main(void)
{
    DDRD |= (1 << PD2); // Set PB5 as output (Arduino digital pin 13)

    while (1) 
    {
        PORTD ^= (1 << PD2); // Toggle LED
        _delay_ms(1750);      // 500ms delay
    }
}
