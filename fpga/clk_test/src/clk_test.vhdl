-- Import the IEEE standard logic library (provides std_logic types)
library IEEE;
-- Use the std_logic_1164 package for digital logic types ('0', '1', 'Z', etc.)
use IEEE.STD_LOGIC_1164.ALL;
-- Use the numeric_std package for arithmetic operations on std_logic_vector
use IEEE.NUMERIC_STD.ALL;

-- Entity declaration: defines the external interface (inputs/outputs) of the module
entity clk_test is
    -- Generics are like compile-time constants that can be overridden
    generic (
        CLK_FREQ : integer := 12000000  -- Clock frequency in Hz (12 MHz on ECP5 Versa board)
    );
    -- Ports are the actual input/output pins
    port (
        clk : in std_logic;                       -- Clock input from FPGA oscillator
        rst : in std_logic;                       -- Reset input (active high - '1' = reset)
        led : out std_logic_vector(7 downto 0)    -- 8-bit output bus for LEDs (7 down to 0)
    );
end clk_test;

-- Architecture: describes the internal behavior/implementation of the entity
architecture rtl of clk_test is
    -- Internal signals go here
    signal not_clk : std_logic := '0';

begin
    -- Your logic implementation goes here

    process(clk)
    begin
        if rising_edge(clk) then
            not_clk <= not not_clk;
        end if;
    end process;

    led(0) <= not_clk;
    led(7 downto 1) <= (others => '0');

end rtl;
