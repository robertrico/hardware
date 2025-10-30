-- Testbench for SIM8-01 Top Level with Real Silicon Intel 8008 CPU Interface
-- This testbench simulates the behavior of a real Intel 8008 chip
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sim8_01_top_tb is
end sim8_01_top_tb;

architecture sim of sim8_01_top_tb is
    component sim8_01_top is
        port(
            clk_100mhz : in std_logic;
            rst : in std_logic;
            debug_led : out std_logic_vector(4 downto 0);
            cpu_data : inout std_logic_vector(7 downto 0);
            cpu_phi1 : out std_logic;
            cpu_phi2 : out std_logic;
            cpu_ready : out std_logic;
            cpu_int : out std_logic;
            cpu_s0 : in std_logic;
            cpu_s1 : in std_logic;
            cpu_s2 : in std_logic;
            cpu_sync : in std_logic
        );
    end component;

    -- Testbench signals
    signal clk_tb : std_logic := '0';
    signal rst_tb : std_logic := '1';
    signal debug_led_tb : std_logic_vector(4 downto 0);
    signal cpu_data_tb : std_logic_vector(7 downto 0);
    signal cpu_phi1_tb : std_logic;
    signal cpu_phi2_tb : std_logic;
    signal cpu_ready_tb : std_logic;
    signal cpu_int_tb : std_logic;
    signal cpu_s0_tb : std_logic := '0';
    signal cpu_s1_tb : std_logic := '0';
    signal cpu_s2_tb : std_logic := '0';
    signal cpu_sync_tb : std_logic := '0';

    -- Simulation control
    signal sim_done : boolean := false;
    constant CLK_PERIOD : time := 10 ns;

    -- Simulated 8008 CPU state
    type cpu_state_type is (RESET, T1_PCI, T2_PCI, T3_PCI, T1I_PCI, T2I_PCI, HALTED);
    signal cpu_state : cpu_state_type := RESET;

    -- Address to fetch from
    signal fetch_addr : std_logic_vector(13 downto 0) := (others => '0');

    -- Data read from memory
    signal data_read : std_logic_vector(7 downto 0);

    -- Control when CPU drives the bus
    signal cpu_drives_bus : std_logic := '0';
    signal cpu_data_out : std_logic_vector(7 downto 0) := (others => '0');

begin
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

    -- DUT instantiation
    dut: sim8_01_top
        port map(
            clk_100mhz => clk_tb,
            rst => rst_tb,
            debug_led => debug_led_tb,
            cpu_data => cpu_data_tb,
            cpu_phi1 => cpu_phi1_tb,
            cpu_phi2 => cpu_phi2_tb,
            cpu_ready => cpu_ready_tb,
            cpu_int => cpu_int_tb,
            cpu_s0 => cpu_s0_tb,
            cpu_s1 => cpu_s1_tb,
            cpu_s2 => cpu_s2_tb,
            cpu_sync => cpu_sync_tb
        );

    -- Bidirectional data bus control
    cpu_data_tb <= cpu_data_out when cpu_drives_bus = '1' else (others => 'Z');

    -- Simulated Intel 8008 CPU behavior
    -- This process simulates how the real 8008 chip behaves on the bus
    -- The real 8008 drives address/data on the bus during PHI1,
    -- and the support chips sample on the rising edge of PHI2
    cpu_simulator: process(cpu_phi1_tb, cpu_phi2_tb, rst_tb)
    begin
        if rst_tb = '1' then
            cpu_state <= RESET;
            fetch_addr <= (others => '0');
            cpu_drives_bus <= '0';
            cpu_data_out <= (others => '0');
            cpu_sync_tb <= '0';
            cpu_s0_tb <= '0';
            cpu_s1_tb <= '0';
            cpu_s2_tb <= '0';

        elsif rising_edge(cpu_phi2_tb) then
            -- State transitions and bus setup happen on rising edge of PHI2
            -- This gives the data time to settle before the next PHI1
            case cpu_state is
                when RESET =>
                    -- Wait for reset to be released
                    if rst_tb = '0' then
                        cpu_state <= T1_PCI;
                        report "CPU: Exiting RESET, starting instruction fetch";
                    end if;

                when T1_PCI =>
                    -- Setup for T2: prepare to drive address high
                    cpu_state <= T2_PCI;

                when T2_PCI =>
                    -- Setup for T3: prepare to read data
                    cpu_state <= T3_PCI;

                when T3_PCI =>
                    -- Latch data from bus NOW while it's still valid
                    -- The DUT drives data during T3 state
                    data_read <= cpu_data_tb;
                    report "CPU T3: Latched data=0x" &
                           to_hstring(cpu_data_tb) &
                           " from address 0x" &
                           to_hstring(fetch_addr);
                    -- Setup for T1I
                    cpu_state <= T1I_PCI;

                when T1I_PCI =>
                    -- Setup for T2I
                    cpu_state <= T2I_PCI;

                when T2I_PCI =>
                    -- Decode instruction (data was already latched in T3)
                    report "CPU T2I: Decoding instruction 0x" & to_hstring(data_read);

                    -- Decode instruction
                    if data_read = x"00" or data_read = x"FF" then
                        report "CPU: Decoded HLT instruction, entering HALTED state";
                        cpu_state <= HALTED;
                    else
                        -- For other instructions, would continue execution
                        report "CPU: Decoded non-HLT instruction, continuing...";
                        fetch_addr <= std_logic_vector(unsigned(fetch_addr) + 1);
                        cpu_state <= T1_PCI;
                    end if;

                when HALTED =>
                    -- Remain halted
                    null;

            end case;

        elsif rising_edge(cpu_phi1_tb) then
            -- Bus activity happens during PHI1 high
            -- Drive outputs that will be sampled by support chips on next PHI2 rising edge
            case cpu_state is
                when T1_PCI =>
                    -- T1: Drive lower 8 bits of address on data bus
                    cpu_drives_bus <= '1';
                    cpu_data_out <= fetch_addr(7 downto 0);
                    cpu_sync_tb <= '1';
                    -- State bits for T1: S2=0, S1=0, S0=1 (from datasheet)
                    cpu_s2_tb <= '0';
                    cpu_s1_tb <= '0';
                    cpu_s0_tb <= '1';
                    report "CPU T1: Driving addr_low=" &
                           integer'image(to_integer(unsigned(fetch_addr(7 downto 0)))) &
                           " on data bus";

                when T2_PCI =>
                    -- T2: Drive upper 6 bits + cycle type (00=PCI) on data bus
                    cpu_drives_bus <= '1';
                    cpu_data_out <= "00" & fetch_addr(13 downto 8);  -- PCI = 00
                    cpu_sync_tb <= '0';  -- SYNC goes low after T1
                    -- State bits for T2: S2=0, S1=1, S0=0
                    cpu_s2_tb <= '0';
                    cpu_s1_tb <= '1';
                    cpu_s0_tb <= '0';
                    report "CPU T2: Driving addr_high=" &
                           integer'image(to_integer(unsigned(fetch_addr(13 downto 8)))) &
                           " + cycle_type=00 (PCI)";

                when T3_PCI =>
                    -- T3: Release bus, read data from memory
                    cpu_drives_bus <= '0';
                    cpu_data_out <= (others => '0');
                    cpu_sync_tb <= '0';
                    -- State bits for T3: S2=0, S1=1, S0=1
                    cpu_s2_tb <= '0';
                    cpu_s1_tb <= '1';
                    cpu_s0_tb <= '1';
                    report "CPU T3: Reading data from memory (bus released), data_bus=0x" &
                           to_hstring(cpu_data_tb);

                when T1I_PCI =>
                    -- T1I: Internal operation, prepare to read data
                    cpu_drives_bus <= '0';
                    cpu_sync_tb <= '0';
                    -- State bits for T1I: S2=1, S1=0, S0=0
                    cpu_s2_tb <= '1';
                    cpu_s1_tb <= '0';
                    cpu_s0_tb <= '0';
                    report "CPU T1I: Internal operation";

                when T2I_PCI =>
                    -- T2I: Still in internal operation
                    cpu_drives_bus <= '0';
                    cpu_sync_tb <= '0';
                    -- State bits for T2I: S2=1, S1=0, S0=1
                    cpu_s2_tb <= '1';
                    cpu_s1_tb <= '0';
                    cpu_s0_tb <= '1';

                when HALTED =>
                    -- Remain halted
                    cpu_drives_bus <= '0';
                    cpu_sync_tb <= '0';
                    -- STOPPED state bits: S2=1, S1=1, S0=0
                    cpu_s2_tb <= '1';
                    cpu_s1_tb <= '1';
                    cpu_s0_tb <= '0';

                when others =>
                    null;

            end case;
        end if;
    end process;

    -- Test stimulus
    test_process: process
    begin
        report "=== Starting SIM8-01 Silicon Interface Test ===";

        -- Hold reset
        rst_tb <= '1';
        wait for 100 ns;

        -- Release reset
        rst_tb <= '0';
        report "Released reset, waiting for CPU to execute...";

        -- Wait for CPU to fetch and decode HLT instruction
        -- Phase clocks are slow (2.2us cycle), need several cycles
        -- Instruction fetch takes: T1 + T2 + T3 + T1I + T2I = 5 states
        -- Each state is one clock cycle (2.2us), so ~11us total
        wait for 5 us;
        report "After 5us: halted=" & std_logic'image(debug_led_tb(2));

        wait for 5 us;
        report "After 10us: halted=" & std_logic'image(debug_led_tb(2));

        wait for 5 us;
        report "After 15us: halted=" & std_logic'image(debug_led_tb(2));

        -- Wait a bit more for DUT to detect STOPPED state
        wait for 5 us;
        report "After 20us: halted=" & std_logic'image(debug_led_tb(2));

        -- Check if CPU halted (debug_led(2) should be high)
        report "Final check: halted=" & std_logic'image(debug_led_tb(2));

        if debug_led_tb(2) = '1' then
            report "=== SUCCESS: CPU Halted (debug_led(2)=1) ===" severity note;
        else
            report "=== FAILURE: CPU did not halt ===" severity error;
        end if;

        -- Additional checks
        report "Debug LEDs: phi1=" & std_logic'image(debug_led_tb(0)) &
               " phi2=" & std_logic'image(debug_led_tb(1)) &
               " halted=" & std_logic'image(debug_led_tb(2)) &
               " read=" & std_logic'image(debug_led_tb(3)) &
               " write=" & std_logic'image(debug_led_tb(4));

        wait for 1 us;
        report "=== SIM8-01 Silicon Interface Test Complete ===";
        sim_done <= true;
        wait;
    end process;

end sim;
