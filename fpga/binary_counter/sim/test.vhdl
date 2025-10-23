-- Import the IEEE standard logic library (provides std_logic types)
library IEEE;
-- Use the std_logic_1164 package for digital logic types
use IEEE.STD_LOGIC_1164.ALL;
-- Use the numeric_std package for arithmetic operations
use IEEE.NUMERIC_STD.ALL;

-- Testbench entity has NO ports - it's a self-contained test environment
-- The "_tb" suffix is a common naming convention for testbenches
entity binary_counter_tb is
end binary_counter_tb;

-- Architecture for the testbench - describes the test setup
architecture sim of binary_counter_tb is

    -- Component declaration: describes the interface of the module we're testing
    component binary_counter is
        generic (
            CLK_FREQ : integer := 100_000_000    -- Default clock frequency
        );
        port (
            clk : in std_logic;                       -- Clock input
            rst : in std_logic;                       -- Reset input
            led : out std_logic_vector(7 downto 0)     -- 8-bit LED output
        );
    end component;

    -- Testbench signals: these connect to the component under test
    signal clk : std_logic := '0';                   -- Clock signal, starts at '0'
    signal rst : std_logic := '1';                   -- Reset signal (active-low: '1'=not reset, '0'=reset)
    signal led : std_logic_vector(7 downto 0);       -- 8-bit LED output
    signal counter : integer := 0;

    -- Clock period definition for simulation
    constant CLK_PERIOD : time := 83.33 ns;  -- Period for ~12 MHz (1/12MHz = 83.33ns)

    -- For simulation, we use MUCH faster frequencies so tests don't take forever
    constant SIM_CLK_FREQ : integer := 1000;   -- 1 kHz simulated clock

    -- Signal to stop the clock generation when simulation is done
    signal sim_done : boolean := false;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: binary_counter
        generic map (
            CLK_FREQ => SIM_CLK_FREQ        -- Use fast frequency for simulation
        )
        port map (
            clk => clk,
            rst => rst,
            led => led
        );

    -- Derive counter value from LED output (invert since LEDs are active-low)
    counter <= to_integer(unsigned(not led));

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
        variable expected_led : std_logic_vector(7 downto 0);
    begin
        -- Test 1: Apply reset and verify initial state (active-low reset)
        report "=== Test 1: Reset ===";
        rst <= '0';  -- Assert reset (active-low)
        wait for 100 ns;
        rst <= '1';  -- De-assert reset
        wait for 20 ns;
        assert counter = 0
            report "FAIL: Counter should be 0 after reset, got " & integer'image(counter)
            severity error;
        report "PASS: Reset sets counter to 0";

        -- Test 2: Verify first few increments with LED matching
        report "=== Test 2: Counter increments 0->1->2->3 ===";
        for i in 1 to 3 loop
            -- Wait for counter to actually change
            wait until counter = i or counter'event;
            wait until counter = i;  -- Make sure we're at the right value
            wait for 1 ns;  -- Signal propagation delay

            -- Check counter value
            assert counter = i
                report "FAIL: Counter should be " & integer'image(i) & ", got " & integer'image(counter)
                severity error;

            -- Expected LED value (active-low, so inverted)
            expected_led := not std_logic_vector(to_unsigned(i, 8));

            -- Check LED matches counter (with inversion)
            assert led = expected_led
                report "FAIL: LED should be " & integer'image(to_integer(unsigned(expected_led))) &
                       " (0x" & to_hstring(expected_led) & ")" &
                       ", got " & integer'image(to_integer(unsigned(led))) &
                       " (0x" & to_hstring(led) & ")" &
                       " for counter=" & integer'image(counter)
                severity error;

            report "PASS: counter=" & integer'image(counter) &
                   ", led=0x" & to_hstring(led) &
                   " (inverted counter value)";
        end loop;

        -- Test 3: Check specific test case (counter=1, led=0xFE)
        report "=== Test 3: Verify counter=1 gives led=0xFE ===";
        wait until counter = 1;
        wait for 1 ns;
        assert led = X"FE"
            report "FAIL: When counter=1, LED should be 0xFE (active-low), got 0x" & to_hstring(led)
            severity error;
        report "PASS: counter=1 produces led=0xFE";

        -- Test 4: Let counter run and spot check several values
        report "=== Test 4: Spot check mid-range values ===";
        wait until counter = 42;
        wait for 1 ns;
        expected_led := not std_logic_vector(to_unsigned(42, 8));
        assert led = expected_led
            report "FAIL: LED mismatch at counter=42"
            severity error;
        report "PASS: counter=42, led=0x" & to_hstring(led);

        wait until counter = 128;
        wait for 1 ns;
        expected_led := not std_logic_vector(to_unsigned(128, 8));
        assert led = expected_led
            report "FAIL: LED mismatch at counter=128"
            severity error;
        report "PASS: counter=128, led=0x" & to_hstring(led);

        -- Test 5: Verify rollover from 255 to 0
        report "=== Test 5: Rollover 254->255->0 ===";
        wait until counter = 254;
        wait for 1 ns;
        report "At counter=254, led=0x" & to_hstring(led);

        -- Wait for counter to actually increment to 255 (not just next clock edge)
        wait until counter = 255;
        wait for 1 ns;
        assert counter = 255
            report "FAIL: Counter should reach 255, got " & integer'image(counter)
            severity error;
        report "PASS: counter=255, led=0x" & to_hstring(led);

        -- Wait for counter to rollover to 0
        wait until counter = 0;
        wait for 1 ns;
        assert counter = 0
            report "FAIL: Counter should rollover to 0 after 255, got " & integer'image(counter)
            severity error;
        expected_led := not std_logic_vector(to_unsigned(0, 8));
        assert led = expected_led
            report "FAIL: LED should be 0xFF (all off, active-low) after rollover, got 0x" & to_hstring(led)
            severity error;
        report "PASS: Counter rolled over to 0, led=0x" & to_hstring(led);

        -- Test 6: Reset during counting (active-low)
        report "=== Test 6: Reset during operation ===";
        wait until counter = 50;
        wait for 1 ns;
        report "Counter at 50, applying reset...";
        rst <= '0';  -- Assert reset (active-low)
        wait for 50 ns;
        rst <= '1';  -- De-assert reset
        wait for 1 ns;
        assert counter = 0
            report "FAIL: Reset should force counter to 0"
            severity error;
        report "PASS: Reset works during counting";

        -- End simulation
        wait for 100 ns;
        sim_done <= true;
        report "========================================";
        report "ALL TESTS PASSED!";
        report "========================================";
        wait;
    end process;

    -- Monitor process: watches for changes on signals
    monitor: process(led)
    begin
        report "LED changed to: " & integer'image(to_integer(unsigned(led))) & " at time " & time'image(now);
    end process;

end sim;
