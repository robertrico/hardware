-- Testbench for SIM8-01 Top Level
-- Tests the complete SIM8-01 system integration

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sim8_01_top_tb is
end sim8_01_top_tb;

architecture sim of sim8_01_top_tb is

    -- Component declaration
    component sim8_01_top is
        generic (
            CLK_FREQ_MHZ : integer := 100;
            CPU_FREQ_KHZ : integer := 500
        );
        port (
            clk           : in    std_logic;
            rst           : in    std_logic;
            cpu_d         : inout std_logic_vector(7 downto 0);
            cpu_s0        : in    std_logic;
            cpu_s1        : in    std_logic;
            cpu_s2        : in    std_logic;
            cpu_sync      : in    std_logic;
            cpu_phi1      : out   std_logic;
            cpu_phi2      : out   std_logic;
            cpu_ready     : out   std_logic;
            cpu_interrupt : out   std_logic;
            mem_addr      : out   std_logic_vector(13 downto 0);
            mem_data      : inout std_logic_vector(7 downto 0);
            mem_read_n    : out   std_logic;
            mem_write_n   : out   std_logic;
            rom_cs_n      : out   std_logic;
            ram_cs_n      : out   std_logic;
            io_addr       : out   std_logic_vector(4 downto 0);
            io_data       : inout std_logic_vector(7 downto 0);
            io_read_n     : out   std_logic;
            io_write_n    : out   std_logic;
            debug_led     : out   std_logic_vector(7 downto 0);
            sw            : in    std_logic_vector(7 downto 1)
        );
    end component;

    -- Testbench signals
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    -- 8008 CPU interface signals (simulated 8008 behavior)
    signal cpu_d         : std_logic_vector(7 downto 0);
    signal cpu_s0        : std_logic := '0';
    signal cpu_s1        : std_logic := '0';
    signal cpu_s2        : std_logic := '0';
    signal cpu_sync      : std_logic := '0';
    signal cpu_phi1      : std_logic;
    signal cpu_phi2      : std_logic;
    signal cpu_ready     : std_logic;
    signal cpu_interrupt : std_logic;

    -- Memory interface signals
    signal mem_addr   : std_logic_vector(13 downto 0);
    signal mem_data   : std_logic_vector(7 downto 0);
    signal mem_read_n : std_logic;
    signal mem_write_n: std_logic;
    signal rom_cs_n   : std_logic;
    signal ram_cs_n   : std_logic;

    -- I/O interface signals
    signal io_addr    : std_logic_vector(4 downto 0);
    signal io_data    : std_logic_vector(7 downto 0);
    signal io_read_n  : std_logic;
    signal io_write_n : std_logic;

    -- Debug signals
    signal debug_led : std_logic_vector(7 downto 0);
    signal sw        : std_logic_vector(7 downto 1) := (others => '0');

    -- Clock parameters
    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz FPGA clock

    -- Expected CPU clock period (for 500 kHz)
    constant CPU_CLK_PERIOD : time := 2 us;  -- 500 kHz = 2 us period

    -- Simulation control
    signal sim_done : boolean := false;

    -- Counters for phase clock validation
    signal phi1_count : integer := 0;
    signal phi2_count : integer := 0;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: sim8_01_top
        generic map (
            CLK_FREQ_MHZ => 100,
            CPU_FREQ_KHZ => 500
        )
        port map (
            clk           => clk,
            rst           => rst,
            cpu_d         => cpu_d,
            cpu_s0        => cpu_s0,
            cpu_s1        => cpu_s1,
            cpu_s2        => cpu_s2,
            cpu_sync      => cpu_sync,
            cpu_phi1      => cpu_phi1,
            cpu_phi2      => cpu_phi2,
            cpu_ready     => cpu_ready,
            cpu_interrupt => cpu_interrupt,
            mem_addr      => mem_addr,
            mem_data      => mem_data,
            mem_read_n    => mem_read_n,
            mem_write_n   => mem_write_n,
            rom_cs_n      => rom_cs_n,
            ram_cs_n      => ram_cs_n,
            io_addr       => io_addr,
            io_data       => io_data,
            io_read_n     => io_read_n,
            io_write_n    => io_write_n,
            debug_led     => debug_led,
            sw            => sw
        );

    -- FPGA clock generation (100 MHz)
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

    -- Main stimulus process
    stim_process: process
    begin
        report "=== SIM8-01 Top Level Test Starting ===";

        -- Apply reset
        report "Applying reset...";
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;

        report "Reset released, monitoring phase clocks...";

        -- Monitor for several CPU clock cycles
        -- At 500 kHz, each cycle is 2 us
        -- Let's observe ~10 complete cycles = 20 us
        wait for 20 us;

        report "Initial observation complete";

        -- Test with different switch configurations
        report "Testing with switches...";
        sw <= "0001010";  -- Arbitrary switch pattern
        wait for 10 us;

        sw <= "1111111";
        wait for 10 us;

        sw <= "0000000";
        wait for 10 us;

        -- Simulate some 8008 state changes
        report "Simulating 8008 state changes...";

        -- State 000 (Fetch cycle T1)
        cpu_s0 <= '0';
        cpu_s1 <= '0';
        cpu_s2 <= '0';
        cpu_sync <= '1';  -- SYNC high during address output
        wait for CPU_CLK_PERIOD;

        cpu_sync <= '0';
        wait for CPU_CLK_PERIOD;

        -- State 001 (Fetch cycle T2)
        cpu_s0 <= '1';
        cpu_s1 <= '0';
        cpu_s2 <= '0';
        wait for CPU_CLK_PERIOD * 2;

        -- Continue for a few more cycles
        wait for 50 us;

        -- End simulation
        report "=== SIM8-01 Top Level Test Complete ===";
        sim_done <= true;
        wait;
    end process;

    -- Monitor process for phase clocks
    monitor_phi1: process(cpu_phi1)
    begin
        if cpu_phi1 = '1' then
            phi1_count <= phi1_count + 1;
            report "PHI1 rising edge #" & integer'image(phi1_count) & " at time " & time'image(now);
        end if;
    end process;

    monitor_phi2: process(cpu_phi2)
    begin
        if cpu_phi2 = '1' then
            phi2_count <= phi2_count + 1;
            report "PHI2 rising edge #" & integer'image(phi2_count) & " at time " & time'image(now);
        end if;
    end process;

    -- Check for overlapping clocks (should never happen!)
    check_overlap: process(cpu_phi1, cpu_phi2)
    begin
        if cpu_phi1 = '1' and cpu_phi2 = '1' then
            report "ERROR: PHI1 and PHI2 overlap detected at " & time'image(now)
                severity error;
        end if;
    end process;

    -- Monitor debug LEDs
    monitor_leds: process(debug_led)
    begin
        report "DEBUG_LED changed to: " &
               integer'image(to_integer(unsigned(debug_led))) &
               " (binary: " &
               std_logic'image(debug_led(7)) &
               std_logic'image(debug_led(6)) &
               std_logic'image(debug_led(5)) &
               std_logic'image(debug_led(4)) &
               std_logic'image(debug_led(3)) &
               std_logic'image(debug_led(2)) &
               std_logic'image(debug_led(1)) &
               std_logic'image(debug_led(0)) &
               ") at time " & time'image(now);
    end process;

end sim;
