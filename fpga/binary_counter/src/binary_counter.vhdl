-- Import the IEEE standard logic library (provides std_logic types)
library IEEE;
-- Use the std_logic_1164 package for digital logic types ('0', '1', 'Z', etc.)
use IEEE.STD_LOGIC_1164.ALL;
-- Use the numeric_std package for arithmetic operations on std_logic_vector
use IEEE.NUMERIC_STD.ALL;

-- Entity declaration: defines the external interface (inputs/outputs) of the module
entity binary_counter is
    -- Generics are like compile-time constants that can be overridden
    generic (
        CLK_FREQ : integer := 100_000_000  -- Clock frequency in Hz (100 MHz on ECP5 Versa board)
    );
    -- Ports are the actual input/output pins
    port (
        clk : in std_logic;                       -- Clock input from FPGA oscillator
        rst : in std_logic;                       -- Reset input (active high - '1' = reset)
        led : out std_logic_vector(7 downto 0);    -- 8-bit output bus for LEDs (7 down to 0)
        out_counter: out integer
    );
end binary_counter;

-- Architecture: describes the internal behavior/implementation of the entity
architecture rtl of binary_counter is
    -- Internal signals go here
    constant MAX_8_BIT_COUNT : integer := 255;
    signal counter : integer range 0 to MAX_8_BIT_COUNT := 0;
    signal led_out : std_logic_vector(7 downto 0) := (others => '0');

begin
    -- Your logic implementation goes here
    process(clk, rst)
    begin
        if rst = '1' then
            counter <= 0;
            led_out <= (others => '0');
        elsif rising_edge(clk) then
            if counter >= MAX_8_BIT_COUNT then
                counter <= 0;
                led_out <= (others => '0');
            elsif counter > 0 then
                counter <= counter + 1;
                led_out <= std_logic_vector(to_unsigned(counter + 1, led_out'length));
            else
                counter <= counter + 1;
                led_out(0) <= '1';
                led_out(7 downto 1) <= (others => '0');
            end if;
        end if;
    end process;

    -- Example: Drive all LEDs off by default
    led <= not led_out;
    out_counter <= counter;

end rtl;
