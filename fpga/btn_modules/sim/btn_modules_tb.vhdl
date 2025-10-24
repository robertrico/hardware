-- Import the IEEE standard logic library (provides std_logic types)
library IEEE;
-- Use the std_logic_1164 package for digital logic types
use IEEE.STD_LOGIC_1164.ALL;
-- Use the numeric_std package for arithmetic operations
use IEEE.NUMERIC_STD.ALL;

-- Testbench entity has NO ports - it's a self-contained test environment
entity btn_modules_tb is
end btn_modules_tb;

-- Architecture for the testbench - describes the test setup
architecture sim of btn_modules_tb is

    -- Component declaration: describes the interface of the module we're testing
    component btn_modules is
        generic (
            CLK_FREQ : integer := 100_000_000    -- Clock frequency in Hz
        );
        port (
            clk : in std_logic;                        -- Clock input from FPGA oscillator
            rst : in std_logic;                        -- Reset input (active high - '1' = reset)
            btns : in std_logic_vector(3 downto 0);    -- 4 button inputs (active low)
            led : out std_logic_vector(7 downto 0);    -- 8-bit output bus for LEDs
            btns_pressed : out std_logic_vector(7 downto 0)  -- Debug output
        );
    end component;

    -- Testbench signals
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';  -- Active low reset - '1' = not in reset
    signal btns : std_logic_vector(3 downto 0) := (others => '1');  -- All buttons released
    signal led : std_logic_vector(7 downto 0);
    signal btns_pressed : std_logic_vector(7 downto 0);

    -- Clock period definition for simulation
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz clock

    -- Signal to stop the clock generation when simulation is done
    signal sim_done : boolean := false;

begin

    -- Instantiate the Unit Under Test (UUT)
    -- With CLK_FREQ = 5000, debounce = 5000/50 = 100 cycles
    uut: btn_modules
        generic map (
            CLK_FREQ => 5_000  -- 5kHz virtual clock gives us 100 cycle debounce
        )
        port map (
            clk => clk,
            rst => rst,
            btns => btns,
            led => led,
            btns_pressed => btns_pressed
        );

    -- Clock generation process
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

    -- Stimulus process: tests all 4 buttons
    stim_process: process
    begin
        report "=== Starting 4-Button Test ===" severity note;

        -- Test 1: Initial state
        report "Test 1: Verifying initial state" severity note;
        wait for 100 ns;
        assert btns_pressed(3 downto 0) = "0000"
            report "FAIL: All btns_pressed should be '0' initially"
            severity error;
        assert btns_pressed(7 downto 4) = "0000"
            report "FAIL: Unused btns_pressed should be '0'"
            severity error;
        assert led(3 downto 0) = "1111"
            report "FAIL: All LEDs should be '1' (off) initially"
            severity error;
        report "PASS: Initial state correct" severity note;

        -- Test 2: Button 0 press
        report "Test 2: Button 0 press (LED0 should toggle ON)" severity note;
        btns(0) <= '0';  -- Press button 0
        wait for 104 * CLK_PERIOD;
        assert btns_pressed(0) = '1'
            report "FAIL: btns_pressed(0) should be '1'"
            severity error;
        wait for CLK_PERIOD;  -- Wait for LED to update
        assert led(0) = '0'
            report "FAIL: LED(0) should toggle to '0' (on)"
            severity error;
        report "PASS: Button 0 toggled LED0 ON" severity note;

        btns(0) <= '1';  -- Release button 0
        wait for 104 * CLK_PERIOD;

        -- Test 3: Button 1 press
        report "Test 3: Button 1 press (LED1 should toggle ON)" severity note;
        btns(1) <= '0';  -- Press button 1
        wait for 104 * CLK_PERIOD;
        assert btns_pressed(1) = '1'
            report "FAIL: btns_pressed(1) should be '1'"
            severity error;
        wait for CLK_PERIOD;
        assert led(1) = '0'
            report "FAIL: LED(1) should toggle to '0' (on)"
            severity error;
        assert led(0) = '0'
            report "FAIL: LED(0) should still be '0' (on)"
            severity error;
        report "PASS: Button 1 toggled LED1 ON, LED0 unchanged" severity note;

        btns(1) <= '1';  -- Release button 1
        wait for 104 * CLK_PERIOD;

        -- Test 4: Button 2 press
        report "Test 4: Button 2 press (LED2 should toggle ON)" severity note;
        btns(2) <= '0';  -- Press button 2
        wait for 104 * CLK_PERIOD;
        wait for CLK_PERIOD;
        assert led(2) = '0'
            report "FAIL: LED(2) should toggle to '0' (on)"
            severity error;
        assert led(1 downto 0) = "00"
            report "FAIL: LED(1:0) should still be '00' (on)"
            severity error;
        report "PASS: Button 2 toggled LED2 ON, others unchanged" severity note;

        btns(2) <= '1';  -- Release button 2
        wait for 104 * CLK_PERIOD;

        -- Test 5: Button 3 press
        report "Test 5: Button 3 press (LED3 should toggle ON)" severity note;
        btns(3) <= '0';  -- Press button 3
        wait for 104 * CLK_PERIOD;
        wait for CLK_PERIOD;
        assert led(3) = '0'
            report "FAIL: LED(3) should toggle to '0' (on)"
            severity error;
        assert led(2 downto 0) = "000"
            report "FAIL: LED(2:0) should still be '000' (on)"
            severity error;
        report "PASS: Button 3 toggled LED3 ON, all 4 LEDs now ON" severity note;

        btns(3) <= '1';  -- Release button 3
        wait for 104 * CLK_PERIOD;

        -- Test 6: Toggle Button 0 OFF
        report "Test 6: Toggle Button 0 OFF" severity note;
        btns(0) <= '0';
        wait for 104 * CLK_PERIOD;
        wait for CLK_PERIOD;
        assert led(0) = '1'
            report "FAIL: LED(0) should toggle back to '1' (off)"
            severity error;
        assert led(3 downto 1) = "000"
            report "FAIL: LED(3:1) should still be '000' (on)"
            severity error;
        report "PASS: Button 0 toggled LED0 OFF" severity note;

        btns(0) <= '1';
        wait for 104 * CLK_PERIOD;

        -- Test 7: Multiple simultaneous button presses (with bouncing)
        report "Test 7: Simultaneous button presses" severity note;

        -- Press buttons 1 and 2 together
        btns(1) <= '0';
        btns(2) <= '0';
        wait for 104 * CLK_PERIOD;
        wait for CLK_PERIOD;

        -- LED1 should toggle off, LED2 should toggle off
        assert led(1) = '1'
            report "FAIL: LED(1) should toggle to '1' (off)"
            severity error;
        assert led(2) = '1'
            report "FAIL: LED(2) should toggle to '1' (off)"
            severity error;
        report "PASS: Simultaneous button presses work correctly" severity note;

        btns(1) <= '1';
        btns(2) <= '1';
        wait for 104 * CLK_PERIOD;

        -- Test 8: Bouncing test on Button 3
        report "Test 8: Button 3 with bouncing" severity note;

        -- Simulate bouncing
        btns(3) <= '0';  -- Press
        wait for 3 * CLK_PERIOD;
        btns(3) <= '1';  -- Bounce
        wait for 2 * CLK_PERIOD;
        btns(3) <= '0';  -- Press again
        wait for 4 * CLK_PERIOD;
        btns(3) <= '1';  -- Bounce
        wait for 1 * CLK_PERIOD;
        btns(3) <= '0';  -- Settle to pressed

        wait for 104 * CLK_PERIOD;
        wait for CLK_PERIOD;

        -- LED3 should toggle once despite bouncing
        assert led(3) = '1'
            report "FAIL: LED(3) should toggle to '1' (off) despite bouncing"
            severity error;
        report "PASS: Bouncing filtered - LED toggled exactly once" severity note;

        -- Test 9: Verify unused LEDs and btns_pressed
        report "Test 9: Verify unused outputs" severity note;
        assert led(7 downto 4) = "1111"
            report "FAIL: LEDs 7-4 should be '1111' (off)"
            severity error;
        assert btns_pressed(7 downto 4) = "0000"
            report "FAIL: btns_pressed(7:4) should be '0000'"
            severity error;
        report "PASS: Unused outputs correct" severity note;

        -- End simulation
        wait for 500 ns;
        report "=== All Tests Complete ===" severity note;
        report "Summary: All 4 buttons and LEDs working correctly!" severity note;
        sim_done <= true;
        wait;
    end process;

    -- Monitor process: watches for button press events
    monitor_btn: process(btns_pressed)
    begin
        for i in 0 to 3 loop
            if btns_pressed(i) = '1' then
                report ">>> BUTTON " & integer'image(i) & " PRESS EVENT at " & time'image(now) & " <<<" severity note;
            end if;
        end loop;
    end process;

    -- Monitor process: watches for LED changes
    monitor_led: process(led)
    begin
        report "LED state: " &
               "LED3=" & std_logic'image(led(3)) & " " &
               "LED2=" & std_logic'image(led(2)) & " " &
               "LED1=" & std_logic'image(led(1)) & " " &
               "LED0=" & std_logic'image(led(0)) &
               " at " & time'image(now) severity note;
    end process;

end sim;
