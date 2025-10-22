-- Import the IEEE standard logic library (provides std_logic types)
library IEEE;
-- Use the std_logic_1164 package for digital logic types ('0', '1', 'Z', etc.)
use IEEE.STD_LOGIC_1164.ALL;
-- Use the numeric_std package for arithmetic operations on std_logic_vector
use IEEE.NUMERIC_STD.ALL;

-- Entity declaration: defines the external interface (inputs/outputs) of the module
entity external_components is
    -- Generics are like compile-time constants that can be overridden
    generic (
        CLK_FREQ : integer := 12000000  -- Clock frequency in Hz (12 MHz on ECP5 Versa board)
    );
    -- Ports are the actual input/output pins
    port (
        clk : in std_logic;                       -- Clock input from FPGA oscillator
        rst : in std_logic;                       -- Reset input (active low - '0' = reset, like KITT)
        btn : in std_logic;                       -- Button input (active low - '0' when pressed)
        led : out std_logic_vector(7 downto 0);   -- 8-bit output bus for LEDs (7 down to 0)
        test_pin7 : out std_logic                 -- Test output on X3 pin 7 (E6) - blinks at ~1 Hz
    );
end external_components;

-- Architecture: describes the internal behavior/implementation of the entity
architecture rtl of external_components is
    -- Debounce constants (20ms debounce at 100 MHz)
    constant DEBOUNCE_TIME : integer := 2000000; -- 20ms * 100MHz

    -- Button synchronization and edge detection
    signal btn_sync : std_logic_vector(1 downto 0) := "11"; -- Synchronized button (start released)
    signal btn_stable : std_logic := '1';                   -- Debounced button state
    signal btn_prev : std_logic := '1';                     -- Previous debounced state for edge detection

    -- Debounce counter
    signal debounce_counter : integer range 0 to DEBOUNCE_TIME := 0;

    -- LED state register (active low: '1' = LED off, '0' = LED on)
    signal led_state : std_logic := '1'; -- Start with LED off

    -- Blink counter for test_pin7 (blink at ~1 Hz with 100 MHz clock)
    constant BLINK_PERIOD : integer := 50000000; -- 0.5s at 100 MHz (toggle every 0.5s = 1 Hz blink)
    signal blink_counter : integer range 0 to BLINK_PERIOD := 0;
    signal blink_state : std_logic := '0'; -- Start with pin low

begin

    -- Main process: button debouncing, edge detection, and LED toggle
    process(clk, rst)
    begin
        if rst = '0' then  -- Active LOW reset (like KITT)
            -- Reset all signals
            btn_sync <= "11";
            btn_stable <= '1';
            btn_prev <= '1';
            debounce_counter <= 0;
            led_state <= '1'; -- LED off (active low)
            blink_counter <= 0;
            blink_state <= '0';

        elsif rising_edge(clk) then
            -- Synchronize button input (prevent metastability)
            btn_sync <= btn_sync(0) & btn;

            -- Debounce logic
            if btn_sync(1) = btn_stable then
                -- Button stable, reset counter
                debounce_counter <= 0;
            else
                -- Button state changed, increment debounce counter
                if debounce_counter < DEBOUNCE_TIME then
                    debounce_counter <= debounce_counter + 1;
                else
                    -- Debounce time elapsed, update stable state
                    btn_stable <= btn_sync(1);
                    debounce_counter <= 0;
                end if;
            end if;

            -- Edge detection - detect falling edge BEFORE updating btn_prev
            -- Detect falling edge (button press: '1' -> '0')
            if btn_prev = '1' and btn_stable = '0' then
                -- Toggle LED state on button press
                led_state <= not led_state;
            end if;

            -- Update previous state AFTER edge detection
            btn_prev <= btn_stable;

            -- Blink counter for test_pin7
            if blink_counter = BLINK_PERIOD - 1 then
                blink_counter <= 0;
                blink_state <= not blink_state; -- Toggle every 0.5s
            else
                blink_counter <= blink_counter + 1;
            end if;
        end if;
    end process;

    -- Output assignments
    led(0) <= led_state;

    -- Turn off all other LEDs (drive high since active low)
    led(7 downto 1) <= (others => '1');

    -- Blink output on test_pin7 (X3 pin 7, FPGA ball E6)
    test_pin7 <= blink_state;

end rtl;
