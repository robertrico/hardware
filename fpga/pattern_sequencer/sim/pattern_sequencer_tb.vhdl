-- Import the IEEE standard logic library (provides std_logic types)
library IEEE;
-- Use the std_logic_1164 package for digital logic types
use IEEE.STD_LOGIC_1164.ALL;
-- Use the numeric_std package for arithmetic operations
use IEEE.NUMERIC_STD.ALL;
use work.pattern_sequencer_pkg.all;  -- Import the package

-- Testbench entity has NO ports - it's a self-contained test environment
-- The "_tb" suffix is a common naming convention for testbenches
entity pattern_sequencer_tb is
end pattern_sequencer_tb;

-- Architecture for the testbench - describes the test setup
architecture sim of pattern_sequencer_tb is

    -- Component declaration: describes the interface of the module we're testing
    component pattern_sequencer is
        generic (
            CLK_FREQ : integer := 100_000_000    -- Default clock frequency
        );
        port (
            clk : in std_logic;                       -- Clock input
            rst : in std_logic;                       -- Reset input
            speed_btn : in std_logic;
            led_btn : in std_logic;
            leds : out std_logic_vector(7 downto 0);    -- 8-bit LED output
            speed_change : out std_logic;
            cur_pat : out led_pattern                       -- Reset input
        );
    end component;

    -- Testbench signals: these connect to the component under test
    signal clk : std_logic := '0';                   -- Clock signal, starts at '0'
    signal rst : std_logic := '0';                   -- Reset signal, starts at '0' (not reset)
    signal speed_btn : std_logic := '1';                   -- Reset signal, starts at '0' (not reset)
    signal led_btn : std_logic := '1';                   -- Reset signal, starts at '0' (not reset)
    signal leds : std_logic_vector(7 downto 0);       -- 8-bit LED output
    signal speed_change : std_logic := '0';                   -- Reset signal, starts at '0' (not reset)
    signal cur_pat : led_pattern := all_blink;

    -- Clock period definition for simulation
    constant CLK_PERIOD : time := 83.33 ns;  -- Period for ~12 MHz (1/12MHz = 83.33ns)

    -- For simulation, we use MUCH faster frequencies so tests don't take forever
    constant SIM_CLK_FREQ : integer := 1000;   -- 1 kHz simulated clock

    -- Signal to stop the clock generation when simulation is done
    signal sim_done : boolean := false;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: pattern_sequencer
        generic map (
            CLK_FREQ => SIM_CLK_FREQ        -- Use 1 kHz instead of 12 MHz
        )
        port map (
            clk => clk,
            rst => rst,
            speed_btn => speed_btn,
            led_btn => led_btn,
            leds => leds,
            speed_change => speed_change,
            cur_pat => cur_pat
        );

    -- Clock generation process: creates a continuous square wave
    clk_process: process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Stimulus process: applies test inputs to the UUT
    stim_process: process
    begin
        -- Apply reset
        rst <= '0';
        wait for 100 ns;
        rst <= '1';

        wait for 1 ns;

        assert leds(0) = '1'
            report "FAIL: LEDs[0] should be '1'"
            severity error;

        speed_btn <= '0';
        wait for 25 * CLK_PERIOD;
        assert speed_change = '1'
            report "Should change speed."
            severity error;
        speed_btn <= '1';

        speed_btn <= '0';
        wait for 5 * CLK_PERIOD;
        assert speed_change = '1'
            report "Should not change speed."
            severity error;
        speed_btn <= '1';

        wait for 21 * CLK_PERIOD;

        speed_btn <= '0';
        wait for 25 * CLK_PERIOD;
        assert speed_change = '0'
            report "Should change speed."
            severity error;
        speed_btn <= '1';

        -- Run test
        wait for 100 ms;

        -- End simulation
        sim_done <= true;
        report "Simulation completed successfully!";
        wait;
    end process;

    -- Monitor process: watches for changes on signals
    monitor: process(leds)
    begin
        report "LED changed to: " & integer'image(to_integer(unsigned(leds))) & " at time " & time'image(now);
        report "Pattern: " & led_pattern'image(cur_pat);
    end process;

end sim;
