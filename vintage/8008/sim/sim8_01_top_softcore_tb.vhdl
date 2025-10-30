-- Testbench for SIM8-01 Top Level Softcore (with i8008 soft core)
-- Tests the complete system: CPU + ROM + RAM

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sim8_01_top_softcore_tb is
end sim8_01_top_softcore_tb;

architecture sim of sim8_01_top_softcore_tb is

    component sim8_01_top is
        port (
            clk : in std_logic;
            rst : in std_logic;
            cpu_phi1 : out std_logic;
            cpu_phi2 : out std_logic;
            debug_led : out std_logic_vector(7 downto 0);
            sw : in std_logic_vector(7 downto 1)
        );
    end component;

    signal clk_tb : std_logic := '0';
    signal rst_tb : std_logic := '0';
    signal cpu_phi1_tb : std_logic;
    signal cpu_phi2_tb : std_logic;
    signal debug_led_tb : std_logic_vector(7 downto 0);
    signal sw_tb : std_logic_vector(7 downto 1) := (others => '0');

    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz
    signal sim_done : boolean := false;

begin

    -- UUT instantiation
    uut: sim8_01_top
        port map (
            clk => clk_tb,
            rst => rst_tb,
            cpu_phi1 => cpu_phi1_tb,
            cpu_phi2 => cpu_phi2_tb,
            debug_led => debug_led_tb,
            sw => sw_tb
        );

    -- Clock generation
    clk_process: process
    begin
        while not sim_done loop
            clk_tb <= '0';
            wait for CLK_PERIOD / 2;
            clk_tb <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Test stimulus
    test_process: process
    begin
        report "=== SIM8-01 System Test Starting ===";

        -- Hold reset
        rst_tb <= '1';
        wait for 100 ns;

        -- Release reset
        rst_tb <= '0';
        report "Reset released - CPU should execute ROM program";
        wait for 20 ns;

        -- Wait for CPU to execute and halt
        -- The ROM has: 0x00 (HLT) at address 0
        -- CPU should fetch 0x00 and halt immediately

        -- Give CPU time to fetch and execute
        wait for 100 ns;
        report "After 100ns: halted=" & std_logic'image(debug_led_tb(2));

        wait for 100 ns;
        report "After 200ns: halted=" & std_logic'image(debug_led_tb(2));

        wait for 200 ns;
        report "After 400ns: halted=" & std_logic'image(debug_led_tb(2));

        wait for 600 ns;
        report "After 1us: halted=" & std_logic'image(debug_led_tb(2));

        wait for 1 us;
        report "After 2us: halted=" & std_logic'image(debug_led_tb(2));

        -- Phase clocks are slow (2.2µs per cycle), need to wait for CPU cycles
        wait for 3 us;
        report "After 5us: halted=" & std_logic'image(debug_led_tb(2));

        wait for 5 us;
        report "After 10us: halted=" & std_logic'image(debug_led_tb(2));

        wait for 10 us;
        report "After 20us: halted=" & std_logic'image(debug_led_tb(2));

        -- Check if halted (debug_led(2) should be high)
        if debug_led_tb(2) = '1' then
            report "=== SUCCESS: CPU Halted (debug_led(2)=1) ===";
        else
            report "=== FAILURE: CPU not halted yet ===";
        end if;

        -- Monitor a bit longer
        wait for 5 us;

        report "=== SIM8-01 System Test Complete ===";
        report "Final debug_led state: " & integer'image(to_integer(unsigned(debug_led_tb)));
        sim_done <= true;
        wait;
    end process;

    -- Monitor debug LEDs
    monitor_process: process(debug_led_tb)
    begin
        report "DEBUG_LED: phi1=" & std_logic'image(debug_led_tb(0)) &
               " phi2=" & std_logic'image(debug_led_tb(1)) &
               " halted=" & std_logic'image(debug_led_tb(2)) &
               " mem_read=" & std_logic'image(debug_led_tb(3)) &
               " mem_write=" & std_logic'image(debug_led_tb(4)) &
               " @" & time'image(now);
    end process;

end sim;
