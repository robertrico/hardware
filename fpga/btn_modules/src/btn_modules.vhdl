-- Import the IEEE standard logic library (provides std_logic types)
library IEEE;
-- Use the std_logic_1164 package for digital logic types ('0', '1', 'Z', etc.)
use IEEE.STD_LOGIC_1164.ALL;
-- Use the numeric_std package for arithmetic operations on std_logic_vector
use IEEE.NUMERIC_STD.ALL;

-- Entity declaration: defines the external interface (inputs/outputs) of the module
entity btn_modules is
    -- Generics are like compile-time constants that can be overridden
    generic (
        CLK_FREQ : integer := 100_000_000  -- Clock frequency in Hz (12 MHz on ECP5 Versa board)
    );
    -- Ports are the actual input/output pins
    port (
        clk : in std_logic;                       -- Clock input from FPGA oscillator
        rst : in std_logic;                       -- Reset input (active high - '1' = reset)
        btns : in std_logic_vector(3 downto 0);
        led : out std_logic_vector(7 downto 0);    -- 8-bit output bus for LEDs (7 down to 0)
        btns_pressed : out std_logic_vector(7 downto 0)  -- Debug output (for simulation/testing)
    );
end btn_modules;


-- Architecture: describes the internal behavior/implementation of the entity
architecture rtl of btn_modules is
    -- Internal signals go here
    -- Component declaration (tells VHDL what debouncer looks like)
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

    signal led_register : std_logic_vector(7 downto 0) := (others => '1');
    signal btns_pressed_internal : std_logic_vector(7 downto 0);
begin
    -- Component instantiation (creates an instance)
    -- Calculate debounce time: 20ms debounce = CLK_FREQ / 50
    D1: debouncer
        generic map(
            DEBOUNCE_TIME => CLK_FREQ / 50  -- 20ms at any clock frequency
        )
        port map(
            clk => clk,
            rst => rst,
            btn => btns(0),
            btn_pressed => btns_pressed_internal(0)
        );
    D2: debouncer
        generic map(
            DEBOUNCE_TIME => CLK_FREQ / 50  -- 20ms at any clock frequency
        )
        port map(
            clk => clk,
            rst => rst,
            btn => btns(1),
            btn_pressed => btns_pressed_internal(1)
        );
    D3: debouncer
        generic map(
            DEBOUNCE_TIME => CLK_FREQ / 50  -- 20ms at any clock frequency
        )
        port map(
            clk => clk,
            rst => rst,
            btn => btns(2),
            btn_pressed => btns_pressed_internal(2)
        );
    D4: debouncer
        generic map(
            DEBOUNCE_TIME => CLK_FREQ / 50  -- 20ms at any clock frequency
        )
        port map(
            clk => clk,
            rst => rst,
            btn => btns(3),
            btn_pressed => btns_pressed_internal(3)
        );

    process(clk)
    begin
        if rising_edge(clk) then
            -- Toggle LEDs on button press
            if (btns_pressed_internal(0) = '1') then
                led_register(0) <= not led_register(0);
            end if;
            if (btns_pressed_internal(1) = '1') then
                led_register(1) <= not led_register(1);
            end if;
            if (btns_pressed_internal(2) = '1') then
                led_register(2) <= not led_register(2);
            end if;
            if (btns_pressed_internal(3) = '1') then
                led_register(3) <= not led_register(3);
            end if;

            -- LEDs 4-7 always OFF
            led_register(7 downto 4) <= (others => '1');
        end if;
    end process;

    -- Assign unused btns_pressed bits (combinational)
    btns_pressed_internal(7 downto 4) <= (others => '0');

    -- Connect internal signal to output port
    btns_pressed <= btns_pressed_internal;
    led <= led_register;
end rtl;
