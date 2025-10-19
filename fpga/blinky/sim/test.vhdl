-- Import the IEEE standard logic library (provides std_logic types)
library IEEE;
-- Use the std_logic_1164 package for digital logic types
use IEEE.STD_LOGIC_1164.ALL;
-- Use the numeric_std package for arithmetic operations
use IEEE.NUMERIC_STD.ALL;

-- Testbench entity has NO ports - it's a self-contained test environment
-- The "_tb" suffix is a common naming convention for testbenches
entity blinky_tb is
end blinky_tb;

-- Architecture for the testbench - describes the test setup
architecture sim of blinky_tb is

    -- Component declaration: describes the interface of the module we're testing
    -- This must match the entity we declared in blink.vhdl
    component blinky is
        generic (
            CLK_FREQ : integer := 12000000;    -- Default clock frequency
            BLINK_FREQ : integer := 1          -- Default blink frequency
        );
        port (
            clk : in std_logic;                       -- Clock input
            rst : in std_logic;                       -- Reset input
            led : out std_logic_vector(7 downto 0)    -- 8-bit LED output (UPDATED!)
        );
    end component;

    -- Testbench signals: these connect to the component under test
    -- We initialize them to known values for simulation
    signal clk : std_logic := '0';                   -- Clock signal, starts at '0'
    signal rst : std_logic := '0';                   -- Reset signal, starts at '0' (not reset)
    signal led : std_logic_vector(7 downto 0);       -- 8-bit LED output (UPDATED!)

    -- Clock period definition for simulation
    -- Real hardware uses 12 MHz, but we can use any period for simulation
    constant CLK_PERIOD : time := 83.33 ns;  -- Period for ~12 MHz (1/12MHz = 83.33ns)

    -- For simulation, we use MUCH faster frequencies so tests don't take forever!
    -- Real hardware: 12,000,000 Hz clock, 1 Hz blink = 12 million cycles per toggle
    -- Simulation: 1,000 Hz clock, 10 Hz blink = 50 cycles per toggle (much faster!)
    constant SIM_CLK_FREQ : integer := 1000;   -- 1 kHz simulated clock
    constant SIM_BLINK_FREQ : integer := 100;   -- 10 Hz simulated blink rate

    -- Signal to stop the clock generation when simulation is done
    signal sim_done : boolean := false;

begin

    -- Instantiate the Unit Under Test (UUT) - this creates an instance of our blinky module
    -- "uut" is the instance name (common abbreviation for "Unit Under Test")
    uut: blinky
        -- Generic map: override the default generic values
        -- This lets us use fast simulation frequencies instead of real hardware frequencies
        generic map (
            CLK_FREQ => SIM_CLK_FREQ,        -- Use 1 kHz instead of 12 MHz
            BLINK_FREQ => SIM_BLINK_FREQ     -- Use 10 Hz instead of 1 Hz
        )
        -- Port map: connect testbench signals to component ports
        -- Format is: component_port => testbench_signal
        port map (
            clk => clk,    -- Connect component's clk port to testbench's clk signal
            rst => rst,    -- Connect component's rst port to testbench's rst signal
            led => led     -- Connect component's led port to testbench's led signal
        );

    -- Clock generation process: creates a continuous square wave
    -- This process runs concurrently with other processes
    clk_process: process
    begin
        -- Loop forever (or until sim_done becomes true)
        while not sim_done loop
            clk <= '0';                -- Set clock low
            wait for CLK_PERIOD / 2;   -- Wait for half a period (41.67 ns)
            clk <= '1';                -- Set clock high
            wait for CLK_PERIOD / 2;   -- Wait for half a period (41.67 ns)
            -- This creates: __--__--__--  (square wave with 83.33ns period)
        end loop;
        wait;  -- Stop this process when sim_done is true
    end process;

    -- Stimulus process: applies test inputs to the UUT
    -- This is where we define our test sequence
    stim_process: process
    begin
        -- Test sequence starts here

        -- 1. Apply reset
        rst <= '1';           -- Assert reset (active high)
        wait for 100 ns;      -- Hold reset for 100 nanoseconds
        rst <= '0';           -- De-assert reset (release)

        -- 2. Let the design run and observe LED blinking
        -- With SIM_BLINK_FREQ = 10 Hz, LED should toggle every 100ms
        -- We'll run for 500ms to see ~5 toggles (2.5 full blink cycles)
        wait for 500 ms;

        -- 3. End the simulation
        sim_done <= true;     -- Signal clock process to stop

        -- Report message (shows in simulator console)
        report "Simulation completed successfully!";
        wait;  -- Stop this process (required at end of testbench)
    end process;

    -- Monitor process: watches for changes on the LED signal
    -- Sensitivity list (led) means this runs whenever 'led' changes
    -- This is optional but helpful for debugging
    monitor: process(led)
    begin
        -- Print a message every time LED changes
        -- 'image converts the value to a string for printing
        -- 'now' is the current simulation time
        report "LED(0) changed to: " & std_logic'image(led(0)) & " at time " & time'image(now);
    end process;

end sim;
