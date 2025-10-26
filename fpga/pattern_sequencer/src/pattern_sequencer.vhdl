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
    signal counter : integer := 0;

    -- Internal signals go here
    signal btns_pressed_internal : std_logic_vector(1 downto 0);

    signal inner_rst : std_logic;

    signal current_pattern : led_pattern;
   
    signal leds_sequence: std_logic_vector(7 downto 0);

    signal cylon_leds : std_logic_vector(7 downto 0);

    signal dn_rst : std_logic;
    signal dn_leds : std_logic_vector(7 downto 0);

    signal up_rst : std_logic;
    signal up_leds : std_logic_vector(7 downto 0);

    signal up_enable : std_logic := '0';
    signal dn_enable : std_logic := '0';
    signal cylon_enable : std_logic := '0';

    component up_down_cylon is
        generic(
            CLK_FREQ : integer;
            COUNT_MODE : string
        );
        port (
            clk : in std_logic;
            rst : in std_logic;
            enable : in std_logic;
            led : out std_logic_vector(7 downto 0)
        );
    end component;

    component debouncer is
        generic(
            DEBOUNCE_TIME : integer
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
            btn => led_btn,
            btn_pressed => btns_pressed_internal(1)
        );
    
    CY: up_down_cylon
        generic map(
            CLK_FREQ => CLK_FREQ,
            COUNT_MODE => "CYLON"
        )
        port map(
            clk => clk,
            rst => rst,
            enable => cylon_enable,
            led => cylon_leds
        );

    DN: up_down_cylon
        generic map(
            CLK_FREQ => CLK_FREQ,
            COUNT_MODE => "DOWN"
        )
        port map(
            clk => clk,
            rst => rst,
            enable => dn_enable,
            led => dn_leds
        );

    UP: up_down_cylon
        generic map(
            CLK_FREQ => CLK_FREQ,
            COUNT_MODE => "UP"
        )
        port map(
            clk => clk,
            rst => rst,
            enable => up_enable,
            led => up_leds
        );

    -- Your logic implementation goes here
    process(clk, rst)
        variable MAX_COUNT : integer := CLK_FREQ / (2 * 5);
    begin
        if rst = '0' then
            speed_change <= '0';
            current_pattern <= all_blink;
            leds_sequence <= (others => '1');
            counter <= 0;
            up_enable <= '0';
            dn_enable <= '0';
            cylon_enable <= '0';
            MAX_COUNT := CLK_FREQ / (2 * 5);
        elsif rising_edge(clk) then
            -- Default: disable all components
            up_enable <= '0';
            dn_enable <= '0';
            cylon_enable <= '0';

            -- Handle pattern button
            if btns_pressed_internal(1) = '1' then
                -- Reset counter for immediate pattern update
                counter <= 0;
                case current_pattern is
                    when all_blink =>
                        leds_sequence <= (others => '1');
                        current_pattern <= up_blink;
                    when up_blink =>
                        leds_sequence <= (others => '1');
                        current_pattern <= down_blink;
                    when down_blink =>
                        leds_sequence <= (others => '1');
                        current_pattern <= cylon_blink;
                    when cylon_blink =>
                        leds_sequence <= "10101010";
                        current_pattern <= alt_blink;
                    when alt_blink =>
                        leds_sequence <= (others => '1');
                        current_pattern <= all_blink;
                end case;
            -- Handle speed button
            elsif btns_pressed_internal(0) = '1' then
                speed_change <= not speed_change;
                -- Check the OLD value (before toggle) to set new speed and counter
                if (speed_change = '0') then  -- Currently slow, switching to fast
                    MAX_COUNT := CLK_FREQ / (2 * 1);
                    counter <= CLK_FREQ / (2 * 1) - 2;  -- Set to trigger in 2 cycles
                else  -- Currently fast, switching to slow
                    MAX_COUNT := CLK_FREQ / (2 * 5);
                    counter <= CLK_FREQ / (2 * 5) - 2;  -- Set to trigger in 2 cycles
                end if;
            -- Handle counter and pattern updates (only if no buttons pressed)
            elsif counter = MAX_COUNT - 1 then
                -- Pattern update counter reached
                counter <= 0;

                -- Enable components for one cycle to make them update
                case current_pattern is
                    when up_blink =>
                        up_enable <= '1';
                        leds_sequence <= up_leds;
                    when down_blink =>
                        dn_enable <= '1';
                        leds_sequence <= dn_leds;
                    when cylon_blink =>
                        cylon_enable <= '1';
                        leds_sequence <= cylon_leds;
                    when all_blink =>
                        leds_sequence <= not leds_sequence;
                    when alt_blink =>
                        leds_sequence(0) <= not leds_sequence(0);
                        leds_sequence(1) <= leds_sequence(0);
                        leds_sequence(2) <= not leds_sequence(2);
                        leds_sequence(3) <= leds_sequence(2);
                        leds_sequence(4) <= not leds_sequence(4);
                        leds_sequence(5) <= leds_sequence(4);
                        leds_sequence(6) <= not leds_sequence(6);
                        leds_sequence(7) <= leds_sequence(6);
                end case;
            else
                counter <= counter + 1;      -- Increment counter by 1
            end if;

        end if;
    end process;

    -- Example: Drive all LEDs off by default
    leds <= leds_sequence;
    cur_pat <= current_pattern;

end rtl;
