-- Import the IEEE standard logic library (provides std_logic types)
library IEEE;
-- Use the std_logic_1164 package for digital logic types ('0', '1', 'Z', etc.)
use IEEE.STD_LOGIC_1164.ALL;
-- Use the numeric_std package for arithmetic operations on std_logic_vector
use IEEE.NUMERIC_STD.ALL;
use work.pattern_sequencer_pkg.all;  -- Import the package

-- Entity declaration: defines the external interface (inputs/outputs) of the module
entity pattern_sequencer is
    -- Generics are like compile-time constants that can be overridden
    generic (
        CLK_FREQ : integer := 100_000_000  -- Clock frequency in Hz (100 MHz on ECP5 Versa board)
    );
    -- Ports are the actual input/output pins
    port (
        clk : in std_logic;                       -- Clock input from FPGA oscillator
        rst : in std_logic;                       -- Reset input (active low - '0' = reset)
        speed_btn : in std_logic;                 -- Speed button input (active low)
        led_btn : in std_logic;                   -- LED button input (active low)
        leds : out std_logic_vector(7 downto 0);  -- 8-bit output bus for LEDs (7 down to 0)
        speed_change : out std_logic;
        cur_pat : out led_pattern              -- Speed change output signal
    );
end pattern_sequencer;

-- Architecture: describes the internal behavior/implementation of the entity
architecture rtl of pattern_sequencer is
    -- Internal signals go here
    signal btns_pressed_internal : std_logic_vector(1 downto 0);

    signal current_pattern : led_pattern;

    component debouncer is
        generic(
            DEBOUNCE_TIME : integer := CLK_FREQ / 50
        );
        port(
            clk : in std_logic;
            rst : in std_logic;
            btn : in std_logic;
            btn_pressed : out std_logic
        );
    end component;
begin

    SD: debouncer
        generic map(
            DEBOUNCE_TIME => CLK_FREQ / 50  -- 20ms at any clock frequency
        )
        port map(
            clk => clk,
            rst => rst,
            btn => speed_btn,
            btn_pressed => btns_pressed_internal(0)
        );

    LD: debouncer
        generic map(
            DEBOUNCE_TIME => CLK_FREQ / 50  -- 20ms at any clock frequency
        )
        port map(
            clk => clk,
            rst => rst,
            btn => speed_btn,
            btn_pressed => btns_pressed_internal(1)
        );

    -- Your logic implementation goes here
    process(clk, rst)
    begin
        if rst = '0' then
            speed_change <= '0';
            current_pattern <= all_blink;
        elsif rising_edge(clk) then
            if btns_pressed_internal(0) = '1' then
                speed_change <= not speed_change;
            end if;
        end if;

    end process;

    -- Example: Drive all LEDs off by default
    leds(7 downto 0) <= (others => '1');
    cur_pat <= current_pattern;

end rtl;
