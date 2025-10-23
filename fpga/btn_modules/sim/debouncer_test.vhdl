library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity debouncer_test is
end debouncer_test;

architecture testbench of debouncer_test is
    -- Component declaration
    component debouncer is
        generic(
            DEBOUNCE_TIME : integer := 2_000_000
        );
        port(
            clk : in std_logic;
            btn : in std_logic;
            btn_pressed : out std_logic
        );
    end component;

    -- Test parameters
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz clock
    constant SHORT_DEBOUNCE : integer := 100;  -- For faster simulation

    -- Signals
    signal clk : std_logic := '0';
    signal btn : std_logic := '1';  -- Button starts released (active low)
    signal btn_pressed : std_logic;

    -- Control signals
    signal sim_done : boolean := false;

begin
    -- Clock generation
    clk_proc: process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    -- Instantiate the debouncer with shorter debounce time for simulation
    dut: debouncer
        generic map(
            DEBOUNCE_TIME => SHORT_DEBOUNCE
        )
        port map(
            clk => clk,
            btn => btn,
            btn_pressed => btn_pressed
        );

    -- Stimulus process
    stim_proc: process
    begin
        report "=== Starting Debouncer Test ===" severity note;

        -- Test 1: Initial state
        report "Test 1: Verifying initial state (button released)" severity note;
        wait for 100 ns;
        assert btn_pressed = '0'
            report "FAIL: btn_pressed should be '0' initially"
            severity error;
        report "PASS: Initial state correct" severity note;

        -- Test 2: Button press with bouncing
        report "Test 2: Button press with bouncing simulation" severity note;
        wait for 200 ns;

        -- Simulate realistic mechanical button bouncing when pressed
        -- This simulates the button making and breaking contact multiple times
        btn <= '0';  -- Initial press
        wait for 3 * CLK_PERIOD;
        btn <= '1';  -- Bounce back
        wait for 2 * CLK_PERIOD;
        btn <= '0';  -- Press again
        wait for 5 * CLK_PERIOD;
        btn <= '1';  -- Bounce back
        wait for 1 * CLK_PERIOD;
        btn <= '0';  -- Press again
        wait for 4 * CLK_PERIOD;
        btn <= '1';  -- Bounce back
        wait for 2 * CLK_PERIOD;
        btn <= '0';  -- Finally settles to pressed (LAST bounce - stable point starts here)

        -- The debouncer should ignore all the bouncing above
        -- Only after the button is stable for DEBOUNCE_TIME should it trigger

        -- Wait for half the debounce time - should NOT trigger yet
        wait for 50 * CLK_PERIOD;
        assert btn_pressed = '0'
            report "FAIL: btn_pressed triggered too early (during debounce period)"
            severity error;

        -- Wait for the remaining debounce time (104 - 50 = 54 more cycles)
        wait for 54 * CLK_PERIOD;

        -- NOW btn_pressed should be '1' for exactly one cycle
        -- This proves the debouncer successfully filtered out all the bouncing
        assert btn_pressed = '1'
            report "FAIL: btn_pressed should be '1' after debounce time (bouncing should be filtered)"
            severity error;
        report "PASS: Button press detected after debounce - bouncing was filtered!" severity note;

        -- Verify it's a single-cycle pulse
        wait for CLK_PERIOD;
        assert btn_pressed = '0'
            report "FAIL: btn_pressed should return to '0' after one cycle"
            severity error;
        report "PASS: Single-cycle pulse verified" severity note;

        -- Test 3: Button held - should not retrigger
        report "Test 3: Button held (no retriggering)" severity note;
        wait for 500 ns;
        assert btn_pressed = '0'
            report "FAIL: btn_pressed should remain '0' while button held"
            severity error;
        report "PASS: No retriggering while held" severity note;

        -- Test 4: Button release with bouncing
        report "Test 4: Button release with bouncing" severity note;

        -- Simulate realistic mechanical button bouncing when released
        btn <= '1';  -- Initial release
        wait for 2 * CLK_PERIOD;
        btn <= '0';  -- Bounce back to pressed
        wait for 3 * CLK_PERIOD;
        btn <= '1';  -- Release again
        wait for 1 * CLK_PERIOD;
        btn <= '0';  -- Bounce back
        wait for 4 * CLK_PERIOD;
        btn <= '1';  -- Finally settles to released (stable point)

        -- Wait for full debounce time
        wait for 104 * CLK_PERIOD;

        -- Should NOT trigger on release (only falling edge triggers)
        -- This verifies the debouncer correctly identifies edge direction
        assert btn_pressed = '0'
            report "FAIL: btn_pressed should not trigger on button release (even with bouncing)"
            severity error;
        report "PASS: No trigger on release - bouncing filtered, edge direction correct!" severity note;

        -- Test 5: Rapid press-release-press sequence
        report "Test 5: Multiple button presses" severity note;

        -- First release the button (it's still pressed from Test 2)
        btn <= '1';
        wait for 104 * CLK_PERIOD;  -- Wait for debounce
        wait for 200 ns;

        -- First press
        btn <= '0';
        wait for 104 * CLK_PERIOD;
        assert btn_pressed = '1'
            report "FAIL: First press not detected"
            severity error;
        wait for CLK_PERIOD;

        -- Release
        btn <= '1';
        wait for 104 * CLK_PERIOD;

        -- Second press
        btn <= '0';
        wait for 104 * CLK_PERIOD;
        assert btn_pressed = '1'
            report "FAIL: Second press not detected"
            severity error;
        report "PASS: Multiple presses detected correctly" severity note;

        -- Test 6: Glitch rejection (very short pulse)
        report "Test 6: Glitch rejection" severity note;

        -- Button should already be released from Test 5, wait for it to settle
        btn <= '1';
        wait for 104 * CLK_PERIOD;

        -- Very short glitch (much shorter than debounce time)
        btn <= '0';
        wait for 5 * CLK_PERIOD;
        btn <= '1';

        -- Wait and verify no trigger (counter should reset before reaching DEBOUNCE_TIME)
        wait for 110 * CLK_PERIOD;
        assert btn_pressed = '0'
            report "FAIL: Glitch was not rejected"
            severity error;
        report "PASS: Short glitch rejected" severity note;

        -- End simulation
        wait for 500 ns;
        report "=== All Tests Complete ===" severity note;
        sim_done <= true;
        wait;
    end process;

    -- Monitor process (optional - reports state changes)
    monitor_proc: process(btn_pressed)
    begin
        if btn_pressed = '1' then
            report ">>> BUTTON PRESS EVENT DETECTED <<<" severity note;
        end if;
    end process;

end testbench;
