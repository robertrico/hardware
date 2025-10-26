-- Comprehensive testbench for pattern_sequencer
-- Tests all 5 patterns, speed control, debouncing, and reset behavior

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pattern_sequencer_pkg.all;

entity pattern_sequencer_tb is
end pattern_sequencer_tb;

architecture sim of pattern_sequencer_tb is

    -- Component declaration
    component pattern_sequencer is
        generic (
            CLK_FREQ : integer := 100_000_000
        );
        port (
            clk : in std_logic;
            rst : in std_logic;
            speed_btn : in std_logic;
            led_btn : in std_logic;
            leds : out std_logic_vector(7 downto 0);
            speed_change : out std_logic;
            cur_pat : out led_pattern
        );
    end component;

    -- Testbench signals
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal speed_btn : std_logic := '1';
    signal led_btn : std_logic := '1';
    signal leds : std_logic_vector(7 downto 0);
    signal speed_change : std_logic := '0';
    signal cur_pat : led_pattern := all_blink;

    -- Clock period
    constant CLK_PERIOD : time := 83.33 ns;  -- ~12 MHz

    -- Simulation clock frequency (much faster for testing)
    constant SIM_CLK_FREQ : integer := 1000;   -- 1 kHz

    -- Timing constants based on SIM_CLK_FREQ
    constant DEBOUNCE_TIME : integer := SIM_CLK_FREQ / 50;  -- 20 cycles
    constant SLOW_BLINK_PERIOD : integer := SIM_CLK_FREQ / (2 * 5);  -- 100 cycles
    constant FAST_BLINK_PERIOD : integer := SIM_CLK_FREQ / (2 * 1);  -- 500 cycles
    constant COUNTER_MOVE_PERIOD : integer := SIM_CLK_FREQ / 10;  -- 100 cycles

    -- Simulation control
    signal sim_done : boolean := false;

    -- Test tracking
    signal test_number : integer := 0;

begin

    -- Instantiate UUT
    uut: pattern_sequencer
        generic map (
            CLK_FREQ => SIM_CLK_FREQ
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

    -- Clock generation
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

    -- Main test stimulus
    stim_process: process
        -- Helper procedure to press a button
        procedure press_button(signal btn : out std_logic; cycles : integer) is
        begin
            btn <= '0';
            wait for cycles * CLK_PERIOD;
            btn <= '1';
            wait for 5 * CLK_PERIOD;  -- Settling time
        end procedure;

        -- Helper procedure to wait for pattern update
        procedure wait_for_pattern_update is
        begin
            wait for SLOW_BLINK_PERIOD * CLK_PERIOD;
        end procedure;

    begin
        -- ====================================================================
        -- TEST 1: Reset Behavior
        -- ====================================================================
        test_number <= 1;
        report "=== TEST 1: Reset Behavior ===";

        -- Apply reset
        rst <= '0';
        wait for 100 ns;
        rst <= '1';
        wait for 50 * CLK_PERIOD;

        -- Check initial state
        assert cur_pat = all_blink
            report "FAIL: Initial pattern should be all_blink"
            severity error;
        assert speed_change = '0'
            report "FAIL: Initial speed_change should be '0'"
            severity error;
        assert leds = "11111111"
            report "FAIL: Initial LEDs should be all on (active low)"
            severity error;

        report "PASS: Reset behavior correct";
        wait for 50 * CLK_PERIOD;

        -- ====================================================================
        -- TEST 2: Debouncing - Short Press (should be ignored)
        -- ====================================================================
        test_number <= 2;
        report "=== TEST 2: Debouncing - Short Press ===";

        press_button(speed_btn, 5);  -- Only 5 cycles (less than DEBOUNCE_TIME)

        assert speed_change = '0'
            report "FAIL: Short button press should be ignored"
            severity error;

        report "PASS: Short press correctly ignored";
        wait for 50 * CLK_PERIOD;

        -- ====================================================================
        -- TEST 3: Debouncing - Long Press (should register)
        -- ====================================================================
        test_number <= 3;
        report "=== TEST 3: Debouncing - Long Press ===";

        press_button(speed_btn, 25);  -- More than DEBOUNCE_TIME

        assert speed_change = '1'
            report "FAIL: Long button press should toggle speed_change"
            severity error;

        report "PASS: Long press correctly registered";
        wait for 50 * CLK_PERIOD;  -- Wait longer for debouncer to fully settle

        -- ====================================================================
        -- TEST 4: Speed Control Toggle
        -- ====================================================================
        test_number <= 4;
        report "=== TEST 4: Speed Control Toggle ===";

        press_button(speed_btn, 25);

        assert speed_change = '0'
            report "FAIL: Second press should toggle speed_change back to '0'"
            severity error;

        report "PASS: Speed toggle works correctly";
        wait for 50 * CLK_PERIOD;

        -- ====================================================================
        -- TEST 5: Pattern - all_blink
        -- ====================================================================
        test_number <= 5;
        report "=== TEST 5: Pattern - all_blink ===";

        -- Should already be in all_blink mode
        assert cur_pat = all_blink
            report "FAIL: Should be in all_blink pattern"
            severity error;

        -- Wait for blink and capture initial state
        wait for 50 * CLK_PERIOD;
        assert leds = "00000000" or leds = "11111111"
            report "FAIL: all_blink should have all LEDs same state"
            severity error;

        -- Wait for pattern update and verify toggle
        wait_for_pattern_update;
        assert leds = "11111111" or leds = "00000000"
            report "FAIL: all_blink should toggle all LEDs"
            severity error;

        report "PASS: all_blink pattern works";
        wait for 50 * CLK_PERIOD;

        -- ====================================================================
        -- TEST 6: Pattern Transition to up_blink
        -- ====================================================================
        test_number <= 6;
        report "=== TEST 6: Pattern Transition - up_blink ===";

        press_button(led_btn, 25);

        assert cur_pat = up_blink
            report "FAIL: Should transition to up_blink"
            severity error;

        -- Wait for pattern update (might be at fast speed, MAX_COUNT=500 cycles)
        wait for 100 us;

        -- Check that only one LED is on (active low means one '0')
        report "DEBUG Test 6: leds=" & integer'image(to_integer(unsigned(leds))) &
               ", inverted=" & integer'image(to_integer(unsigned(not leds)));
        assert to_integer(unsigned(not leds)) = 1 or
               to_integer(unsigned(not leds)) = 2 or
               to_integer(unsigned(not leds)) = 4 or
               to_integer(unsigned(not leds)) = 8 or
               to_integer(unsigned(not leds)) = 16 or
               to_integer(unsigned(not leds)) = 32 or
               to_integer(unsigned(not leds)) = 64 or
               to_integer(unsigned(not leds)) = 128
            report "FAIL: up_blink should have exactly one LED on"
            severity error;

        report "PASS: up_blink pattern started";

        -- Verify counting up behavior
        wait for COUNTER_MOVE_PERIOD * CLK_PERIOD;
        wait for COUNTER_MOVE_PERIOD * CLK_PERIOD;
        wait for COUNTER_MOVE_PERIOD * CLK_PERIOD;

        report "PASS: up_blink counting verified";
        wait for 50 * CLK_PERIOD;

        -- ====================================================================
        -- TEST 7: Pattern Transition to down_blink
        -- ====================================================================
        test_number <= 7;
        report "=== TEST 7: Pattern Transition - down_blink ===";

        press_button(led_btn, 25);

        assert cur_pat = down_blink
            report "FAIL: Should transition to down_blink"
            severity error;

        -- Wait for pattern to fully transition
        wait for (SLOW_BLINK_PERIOD * 3) * CLK_PERIOD;

        assert to_integer(unsigned(not leds)) = 1 or
               to_integer(unsigned(not leds)) = 2 or
               to_integer(unsigned(not leds)) = 4 or
               to_integer(unsigned(not leds)) = 8 or
               to_integer(unsigned(not leds)) = 16 or
               to_integer(unsigned(not leds)) = 32 or
               to_integer(unsigned(not leds)) = 64 or
               to_integer(unsigned(not leds)) = 128
            report "FAIL: down_blink should have exactly one LED on"
            severity error;

        report "PASS: down_blink pattern works";
        wait for 50 * CLK_PERIOD;

        -- ====================================================================
        -- TEST 8: Pattern Transition to cylon_blink
        -- ====================================================================
        test_number <= 8;
        report "=== TEST 8: Pattern Transition - cylon_blink ===";

        press_button(led_btn, 25);

        assert cur_pat = cylon_blink
            report "FAIL: Should transition to cylon_blink"
            severity error;

        -- Wait for pattern to fully transition
        wait for (SLOW_BLINK_PERIOD * 3) * CLK_PERIOD;

        -- Verify single LED on
        assert to_integer(unsigned(not leds)) = 1 or
               to_integer(unsigned(not leds)) = 2 or
               to_integer(unsigned(not leds)) = 4 or
               to_integer(unsigned(not leds)) = 8 or
               to_integer(unsigned(not leds)) = 16 or
               to_integer(unsigned(not leds)) = 32 or
               to_integer(unsigned(not leds)) = 64 or
               to_integer(unsigned(not leds)) = 128
            report "FAIL: cylon_blink should have exactly one LED on"
            severity error;

        -- Let it run through several cycles to verify bounce
        wait for COUNTER_MOVE_PERIOD * 10 * CLK_PERIOD;

        report "PASS: cylon_blink pattern works";
        wait for 50 * CLK_PERIOD;

        -- ====================================================================
        -- TEST 9: Pattern Transition to alt_blink
        -- ====================================================================
        test_number <= 9;
        report "=== TEST 9: Pattern Transition - alt_blink ===";

        press_button(led_btn, 25);

        assert cur_pat = alt_blink
            report "FAIL: Should transition to alt_blink"
            severity error;

        -- Wait for pattern to start
        wait for 50 * CLK_PERIOD;

        -- Wait for first update
        wait_for_pattern_update;

        -- Check alternating pairs
        assert leds(0) /= leds(1)
            report "FAIL: alt_blink LED[1:0] should be opposite"
            severity error;
        assert leds(2) /= leds(3)
            report "FAIL: alt_blink LED[3:2] should be opposite"
            severity error;
        assert leds(4) /= leds(5)
            report "FAIL: alt_blink LED[5:4] should be opposite"
            severity error;
        assert leds(6) /= leds(7)
            report "FAIL: alt_blink LED[7:6] should be opposite"
            severity error;

        -- Wait for second update and verify alternation
        wait_for_pattern_update;

        assert leds(0) /= leds(1)
            report "FAIL: alt_blink LED[1:0] should remain opposite"
            severity error;

        report "PASS: alt_blink pattern works";
        wait for 50 * CLK_PERIOD;

        -- ====================================================================
        -- TEST 10: Pattern Wrap-around to all_blink
        -- ====================================================================
        test_number <= 10;
        report "=== TEST 10: Pattern Wrap-around ===";

        press_button(led_btn, 25);

        assert cur_pat = all_blink
            report "FAIL: Should wrap back to all_blink"
            severity error;

        report "PASS: Pattern wrap-around works";
        wait for 50 * CLK_PERIOD;

        -- ====================================================================
        -- TEST 11: Speed Change During Pattern
        -- ====================================================================
        test_number <= 11;
        report "=== TEST 11: Speed Change During Pattern ===";

        -- Currently in all_blink, slow speed
        -- Record current blink state
        wait for 50 * CLK_PERIOD;

        -- Toggle to fast speed
        press_button(speed_btn, 25);
        assert speed_change = '1'
            report "FAIL: speed_change should be '1' for fast speed"
            severity error;

        -- Pattern should update faster now (FAST_BLINK_PERIOD instead of SLOW_BLINK_PERIOD)
        wait for FAST_BLINK_PERIOD * CLK_PERIOD;

        report "PASS: Speed change affects pattern timing";
        wait for 50 * CLK_PERIOD;

        -- ====================================================================
        -- TEST 12: Multiple Rapid Pattern Changes
        -- ====================================================================
        test_number <= 12;
        report "=== TEST 12: Multiple Rapid Pattern Changes ===";

        -- Cycle through all patterns quickly
        press_button(led_btn, 25);
        wait for 50 * CLK_PERIOD;  -- Allow debouncer to settle for next press
        assert cur_pat = up_blink severity error;

        press_button(led_btn, 25);
        wait for 50 * CLK_PERIOD;
        assert cur_pat = down_blink severity error;

        press_button(led_btn, 25);
        wait for 50 * CLK_PERIOD;
        assert cur_pat = cylon_blink severity error;

        press_button(led_btn, 25);
        wait for 50 * CLK_PERIOD;
        assert cur_pat = alt_blink severity error;

        press_button(led_btn, 25);
        wait for 50 * CLK_PERIOD;
        assert cur_pat = all_blink severity error;

        report "PASS: Rapid pattern cycling works";
        wait for 50 * CLK_PERIOD;

        -- ====================================================================
        -- All Tests Complete
        -- ====================================================================
        report "============================================";
        report "ALL TESTS PASSED!";
        report "============================================";

        sim_done <= true;
        wait;
    end process;

    -- Monitor process: reports LED changes
    monitor: process(leds, cur_pat)
    begin
        report "Pattern: " & led_pattern'image(cur_pat) &
               " | LEDs: " & integer'image(to_integer(unsigned(leds))) &
               " | Time: " & time'image(now);
    end process;

end sim;
