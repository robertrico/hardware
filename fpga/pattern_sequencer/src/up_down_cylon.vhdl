-- Import the IEEE standard logic library (provides std_logic types)
library IEEE;
-- Use the std_logic_1164 package for digital logic types ('0', '1', 'Z', etc.)
use IEEE.STD_LOGIC_1164.ALL;
-- Use the numeric_std package for arithmetic operations on std_logic_vector
use IEEE.NUMERIC_STD.ALL;

-- Entity declaration: defines the external interface (inputs/outputs) of the module
entity up_down_cylon is
    -- Generics are like compile-time constants that can be overridden
    generic (
        CLK_FREQ : integer := 100000000;
        COUNT_MODE : string := "CYLON"  -- "UP" or "DOWN" or "CYLON"
    );
    -- Ports are the actual input/output pins
    port (
        clk : in std_logic;                       -- Clock input from FPGA oscillator
        rst : in std_logic;                       -- Reset input from SW1 (GSRN button, active low)
        led : out std_logic_vector(7 downto 0)    -- 8-bit output bus for LEDs (7 down to 0)
    );
end up_down_cylon;

-- Architecture: describes the internal behavior/implementation of the entity
architecture rtl of up_down_cylon is

    -- FSM State Type Definition
    -- Two states: moving right (0->7) and moving left (7->0)
    type state_type is (MOVING_RIGHT, MOVING_LEFT);

    -- FSM State Signals
    signal current_state : state_type := MOVING_RIGHT;
    signal next_state    : state_type;

    -- Position tracking (which LED is currently lit: 0 to 7)
    signal led_position      : unsigned(2 downto 0) := (others => '0');  -- 0-7
    signal next_led_position : unsigned(2 downto 0);

    -- Timing control - determines speed of LED movement
    constant MOVE_PERIOD : integer := CLK_FREQ / 10;  -- Move LED every 100ms (10 Hz)
    signal move_counter  : integer range 0 to MOVE_PERIOD := 0;
    signal move_tick     : std_logic := '0';  -- Pulse when it's time to move

begin

    -- Timing generation process: creates move_tick pulse every MOVE_PERIOD clocks
    timing_gen: process(clk, rst)
    begin
        if rst = '0' then  -- Active low reset (SW1 pressed)
            move_counter <= 0;
            move_tick <= '0';
        elsif rising_edge(clk) then
            if move_counter = MOVE_PERIOD - 1 then
                move_counter <= 0;
                move_tick <= '1';  -- Pulse high for one clock
            else
                move_counter <= move_counter + 1;
                move_tick <= '0';
            end if;
        end if;
    end process;

    -- State register process: updates current state on clock edge
    state_reg: process(clk, rst)
    begin
        if rst = '0' then  -- Active low reset (SW1 pressed)
            if COUNT_MODE = "DOWN" then
                current_state <= MOVING_LEFT;
            else 
                current_state <= MOVING_RIGHT;
            end if;
            led_position <= (others => '0');
        elsif rising_edge(clk) then
            if move_tick = '1' then
                current_state <= next_state;
                led_position <= next_led_position;
            end if;
        end if;
    end process;

    -- Next state logic: determines state transitions and position updates
    next_state_logic: process(current_state, led_position)
    begin
        -- Default: maintain current state and position
        next_state <= current_state;
        next_led_position <= led_position;

        case current_state is
            when MOVING_RIGHT =>
                if led_position = 7 then
                    -- Hit right edge, reverse direction
                    if COUNT_MODE = "UP" then
                        next_led_position <= (others => '0');  -- Start moving left
                    else
                        next_led_position <= led_position - 1;  -- Start moving left
                        next_state <= MOVING_LEFT;
                    end if;
                else
                    -- Keep moving right
                    next_state <= MOVING_RIGHT;
                    next_led_position <= led_position + 1;
                end if;

            when MOVING_LEFT =>
                if led_position = 0 then
                    -- Hit left edge, reverse direction
                    if COUNT_MODE = "DOWN" then
                        next_led_position <= to_unsigned(7,3);  -- Start moving left
                    else
                        next_state <= MOVING_RIGHT;
                        next_led_position <= led_position + 1;  -- Start moving right
                    end if;
                else
                    -- Keep moving left
                    next_state <= MOVING_LEFT;
                    next_led_position <= led_position - 1;
                end if;
        end case;
    end process;

    -- Output logic: decode led_position to LED pattern
    -- Only one LED lit at a time at the current position
    output_logic: process(led_position)
    begin
        led <= (others => '1');  -- All LEDs off (active low)
        led(to_integer(led_position)) <= '0';  -- Turn on current LED (active low)
    end process;

end rtl;
