-- Import the IEEE standard logic library (provides std_logic types)
library IEEE;
-- Use the std_logic_1164 package for digital logic types ('0', '1', 'Z', etc.)
use IEEE.STD_LOGIC_1164.ALL;
-- Use the numeric_std package for arithmetic operations on std_logic_vector
use IEEE.NUMERIC_STD.ALL;

-- Entity declaration: defines the external interface (inputs/outputs) of the module
entity blinky is
    -- Generics are like compile-time constants that can be overridden
    generic (
        CLK_FREQ : integer := 12000000;  -- Clock frequency in Hz (12 MHz on ECP5 Versa board)
        BLINK_FREQ : integer := 1        -- Desired blink rate in Hz (1 Hz = 1 blink per second)
    );
    -- Ports are the actual input/output pins
    port (
        clk : in std_logic;                       -- Clock input from FPGA oscillator
        rst : in std_logic;                       -- Reset input (active high - '1' = reset)
        led : out std_logic_vector(7 downto 0)    -- 8-bit output bus for LEDs (7 down to 0)
    );
end blinky;

-- Architecture: describes the internal behavior/implementation of the entity
architecture rtl of blinky is
    -- Calculate how many clock cycles to count before toggling LED
    -- Divide by 2 because we toggle (not full cycle), so 6M counts = 0.5 sec
    constant MAX_COUNT : integer := CLK_FREQ / (2 * BLINK_FREQ);

    -- Internal signal to count clock cycles (0 to 6,000,000)
    -- The "range" constraint helps synthesis optimize the counter size
    signal counter : integer range 0 to MAX_COUNT := 0;

    -- Internal signal to hold current LED state (on or off)
    -- Initialized to '0' (LED off at startup)
    signal led_state : std_logic := '0';
begin

    -- Process: a sequential block that executes when any signal in sensitivity list changes
    -- Sensitivity list: (clk, rst) means run this process when clk OR rst changes
    process(clk, rst)
    begin
        -- Check reset first (highest priority) - this is "asynchronous reset"
        -- When rst is '1', immediately reset counter and LED regardless of clock
        if rst = '1' then
            counter <= 0;           -- Reset counter to 0
            led_state <= '0';       -- Turn LED off

        -- If not resetting, check for rising edge of clock (0 -> 1 transition)
        -- This makes it a "synchronous" design - changes only happen on clock edge
        elsif rising_edge(clk) then

            -- Check if we've counted up to our target (6,000,000 - 1)
            -- We use MAX_COUNT - 1 because we start counting from 0
            if counter = MAX_COUNT - 1 then
                counter <= 0;                -- Reset counter back to 0
                led_state <= not led_state;  -- Toggle LED state (0->1 or 1->0)

            -- If we haven't reached the target yet, keep counting
            else
                counter <= counter + 1;      -- Increment counter by 1
            end if;
        end if;
    end process;

    -- Concurrent signal assignments (happen continuously, not just on clock edges)
    -- Drive LED0 with the blinking led_state signal
    led(0) <= led_state;

    -- Drive all other LEDs (7 down to 1) to '0' (off)
    -- The "(others => '0')" syntax means "set all remaining bits to 0"
    led(7 downto 1) <= (others => '0');

end rtl;