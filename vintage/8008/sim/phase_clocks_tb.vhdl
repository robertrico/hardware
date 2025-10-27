-- Comprehensive Testbench for phase_clocks
-- Tests non-overlapping phase clock generation for Intel 8008
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity phase_clocks_tb is
end phase_clocks_tb;

architecture sim of phase_clocks_tb is
    -- Component declaration
    component phase_clocks is
        Port (
            clk_in : in STD_LOGIC;
            reset  : in STD_LOGIC;
            phi1   : out STD_LOGIC;
            phi2   : out STD_LOGIC
        );
    end component;

    -- Testbench signals
    signal clk_in : STD_LOGIC := '0';
    signal reset  : STD_LOGIC := '1';
    signal phi1   : STD_LOGIC;
    signal phi2   : STD_LOGIC;

    -- Clock parameters
    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz input clock
    signal sim_done : boolean := false;

    -- Measurement signals
    signal phi1_rising_count : integer := 0;
    signal phi2_rising_count : integer := 0;
    signal overlap_detected : boolean := false;
    signal phi1_last : std_logic := '0';
    signal phi2_last : std_logic := '0';

    -- Timing measurements
    signal phi1_high_time : time := 0 ns;
    signal phi2_high_time : time := 0 ns;
    signal phi1_rise_time : time := 0 ns;
    signal phi2_rise_time : time := 0 ns;
    signal phi1_fall_time : time := 0 ns;
    signal phi2_fall_time : time := 0 ns;
    signal dead_time_1 : time := 0 ns;  -- After phi1 falls
    signal dead_time_2 : time := 0 ns;  -- After phi2 falls

    -- Expected values based on code analysis
    constant CLOCK_DIVIDER : integer := 200;
    constant DEAD_CLOCK_DIVIDER : integer := 50;
    constant EXPECTED_PHI_PERIOD : time := (CLOCK_DIVIDER + DEAD_CLOCK_DIVIDER) * CLK_PERIOD;
    constant EXPECTED_FULL_CYCLE : time := 2 * EXPECTED_PHI_PERIOD;
    constant EXPECTED_DEAD_TIME : time := DEAD_CLOCK_DIVIDER * CLK_PERIOD;
    constant EXPECTED_ACTIVE_TIME : time := CLOCK_DIVIDER * CLK_PERIOD;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: phase_clocks
        port map (
            clk_in => clk_in,
            reset  => reset,
            phi1   => phi1,
            phi2   => phi2
        );

    -- Clock generation process
    clk_process: process
    begin
        while not sim_done loop
            clk_in <= '0';
            wait for CLK_PERIOD / 2;
            clk_in <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Main stimulus process
    stim_process: process
        variable test_cycles : integer := 0;
    begin
        report "=== Phase Clocks Comprehensive Test Starting ===";
        report "Input Clock: 100 MHz (10 ns period)";
        report "Expected phi1/phi2 frequency: 200 kHz";
        report "Expected full cycle time: " & time'image(EXPECTED_FULL_CYCLE);
        report "Expected active phase time: " & time'image(EXPECTED_ACTIVE_TIME);
        report "Expected dead time: " & time'image(EXPECTED_DEAD_TIME);

        -- Test 1: Reset behavior
        report "TEST 1: Reset behavior";
        reset <= '1';
        wait for 200 ns;
        assert phi1 = '1' report "FAIL: phi1 should be HIGH during reset" severity error;
        assert phi2 = '0' report "FAIL: phi2 should be LOW during reset" severity error;
        report "PASS: Reset state correct";

        -- Test 2: Release reset and observe startup
        report "TEST 2: Reset release and startup";
        reset <= '0';
        wait for 100 ns;
        report "PASS: Reset released";

        -- Test 3: Run for multiple complete cycles
        report "TEST 3: Running for 5 complete cycles";
        wait for 5 * EXPECTED_FULL_CYCLE;

        if phi1_rising_count >= 5 then
            report "PASS: Detected " & integer'image(phi1_rising_count) & " phi1 rising edges";
        else
            report "FAIL: Only detected " & integer'image(phi1_rising_count) & " phi1 rising edges (expected >= 5)" severity error;
        end if;

        if phi2_rising_count >= 5 then
            report "PASS: Detected " & integer'image(phi2_rising_count) & " phi2 rising edges";
        else
            report "FAIL: Only detected " & integer'image(phi2_rising_count) & " phi2 rising edges (expected >= 5)" severity error;
        end if;

        -- Test 4: Check for any overlaps
        report "TEST 4: Checking for clock overlap violations";
        if overlap_detected then
            report "FAIL: Clock overlap detected during test!" severity error;
        else
            report "PASS: No clock overlaps detected";
        end if;

        -- Test 5: Measure timing accuracy
        report "TEST 5: Timing measurements";
        report "  Measured phi1 high time: " & time'image(phi1_high_time);
        report "  Measured phi2 high time: " & time'image(phi2_high_time);
        report "  Measured dead time after phi1: " & time'image(dead_time_1);
        report "  Measured dead time after phi2: " & time'image(dead_time_2);

        -- Verify timing within tolerance (allow ±1 clock period)
        if phi1_high_time >= EXPECTED_ACTIVE_TIME - CLK_PERIOD and
           phi1_high_time <= EXPECTED_ACTIVE_TIME + CLK_PERIOD then
            report "PASS: phi1 active time correct";
        else
            report "FAIL: phi1 active time out of range" severity error;
        end if;

        if dead_time_1 >= EXPECTED_DEAD_TIME - CLK_PERIOD and
           dead_time_1 <= EXPECTED_DEAD_TIME + CLK_PERIOD then
            report "PASS: dead time 1 correct";
        else
            report "FAIL: dead time 1 out of range" severity error;
        end if;

        -- Test 6: Reset during operation
        report "TEST 6: Reset during operation";
        wait for EXPECTED_PHI_PERIOD / 2;  -- Reset in middle of cycle
        reset <= '1';
        wait for 50 ns;
        assert phi1 = '1' report "FAIL: phi1 should be HIGH during reset" severity error;
        assert phi2 = '0' report "FAIL: phi2 should be LOW during reset" severity error;
        reset <= '0';
        wait for 2 * EXPECTED_FULL_CYCLE;
        report "PASS: Reset during operation successful";

        -- Test 7: Long duration test
        report "TEST 7: Extended operation test (20 cycles)";
        wait for 20 * EXPECTED_FULL_CYCLE;
        report "PASS: Extended operation completed";

        report "=== All Phase Clock Tests Complete ===";
        report "Total phi1 rising edges: " & integer'image(phi1_rising_count);
        report "Total phi2 rising edges: " & integer'image(phi2_rising_count);

        sim_done <= true;
        wait;
    end process;

    -- Continuous overlap detection process (CRITICAL SAFETY CHECK)
    overlap_check: process(phi1, phi2)
    begin
        if phi1 = '1' and phi2 = '1' then
            report "CRITICAL ERROR: phi1 and phi2 overlap at " & time'image(now) severity error;
            overlap_detected <= true;
        end if;
    end process;

    -- Edge detection and counting process
    edge_detect: process(clk_in)
    begin
        if rising_edge(clk_in) then
            phi1_last <= phi1;
            phi2_last <= phi2;

            -- Count rising edges
            if phi1 = '1' and phi1_last = '0' then
                phi1_rising_count <= phi1_rising_count + 1;
                phi1_rise_time <= now;
                report "phi1 rising edge #" & integer'image(phi1_rising_count) & " at " & time'image(now);
            end if;

            if phi2 = '1' and phi2_last = '0' then
                phi2_rising_count <= phi2_rising_count + 1;
                phi2_rise_time <= now;
                report "phi2 rising edge #" & integer'image(phi2_rising_count) & " at " & time'image(now);
            end if;

            -- Measure falling edges and calculate high time
            if phi1 = '0' and phi1_last = '1' then
                phi1_fall_time <= now;
                phi1_high_time <= now - phi1_rise_time;
                report "phi1 falling edge at " & time'image(now) & ", high time: " & time'image(now - phi1_rise_time);
            end if;

            if phi2 = '0' and phi2_last = '1' then
                phi2_fall_time <= now;
                phi2_high_time <= now - phi2_rise_time;
                report "phi2 falling edge at " & time'image(now) & ", high time: " & time'image(now - phi2_rise_time);
            end if;

            -- Measure dead time (time between falling edge and next rising edge)
            if phi2 = '1' and phi2_last = '0' and phi1_fall_time > 0 ns then
                dead_time_1 <= now - phi1_fall_time;
                report "Dead time after phi1: " & time'image(now - phi1_fall_time);
            end if;

            if phi1 = '1' and phi1_last = '0' and phi2_fall_time > 0 ns then
                dead_time_2 <= now - phi2_fall_time;
                report "Dead time after phi2: " & time'image(now - phi2_fall_time);
            end if;
        end if;
    end process;

    -- Frequency measurement process
    freq_check: process
        variable cycle_start : time;
        variable cycle_count : integer := 0;
    begin
        wait until phi1 = '1' and phi1'event;
        cycle_start := now;
        wait until phi1 = '1' and phi1'event;

        if cycle_count = 0 then
            report "First full cycle period: " & time'image(now - cycle_start);
            if now - cycle_start /= EXPECTED_PHI_PERIOD then
                report "WARNING: Cycle period differs from expected" severity warning;
            end if;
        end if;

        cycle_count := cycle_count + 1;
    end process;

end sim;
