-- Import the IEEE standard logic library (provides std_logic types)
library IEEE;
-- Use the std_logic_1164 package for digital logic types
use IEEE.STD_LOGIC_1164.ALL;
-- Use the numeric_std package for arithmetic operations
use IEEE.NUMERIC_STD.ALL;

-- Testbench entity has NO ports - it's a self-contained test environment
-- The "_tb" suffix is a common naming convention for testbenches
entity kitt_tb is
end kitt_tb;

-- Architecture for the testbench - describes the test setup
architecture sim of kitt_tb is

    -- Component declaration: describes the interface of the module we're testing
    component kitt is
        generic (
            CLK_FREQ : integer := 12000000    -- Default clock frequency
        );
        port (
            clk : in std_logic;                       -- Clock input
            rst : in std_logic;                       -- Reset input
            led : out std_logic_vector(7 downto 0)    -- 8-bit LED output
        );
    end component;

    -- Testbench signals: these connect to the component under test
    signal clk : std_logic := '0';                   -- Clock signal, starts at '0'
    signal rst : std_logic := '0';                   -- Reset signal, starts at '0' (not reset)
    signal led : std_logic_vector(7 downto 0);       -- 8-bit LED output

    -- Clock period definition for simulation
    constant CLK_PERIOD : time := 83.33 ns;  -- Period for ~12 MHz (1/12MHz = 83.33ns)

    -- For simulation, we use MUCH faster frequencies so tests don't take forever
    constant SIM_CLK_FREQ : integer := 1000;   -- 1 kHz simulated clock

    -- Signal to stop the clock generation when simulation is done
    signal sim_done : boolean := false;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: kitt
        generic map (
            CLK_FREQ => SIM_CLK_FREQ        -- Use 1 kHz instead of 12 MHz
        )
        port map (
            clk => clk,
            rst => rst,
            led => led
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
        rst <= '1';
        wait for 100 ns;
        rst <= '0';

        -- Run test
        wait for 500 ms;

        -- End simulation
        sim_done <= true;
        report "Simulation completed successfully!";
        wait;
    end process;

    -- Monitor process: watches for changes on signals
    monitor: process(led)
    begin
        report "LED changed to: " & integer'image(to_integer(unsigned(led))) & " at time " & time'image(now);
    end process;

end sim;
