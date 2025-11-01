-------------------------------------------------------------------------------
-- Intel SIM8-01 Recreation - Silicon Interface Top Level
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Robert Rico
--
-- Top-level design for interfacing with a real vintage Intel 8008 CPU chip.
-- This module handles:
--   - Address demultiplexing from the 8008's multiplexed data bus
--   - Memory interface (2K ROM + 1K RAM)
--   - Bidirectional data bus control
--   - Two-phase clock generation
--
-- Based on Intel SIM8-01 reference design with adaptations for FPGA.
--
-- License: MIT (see LICENSE.txt)
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sim8_01_top is
    port(
        -- System clock and reset (active high)
        clk_100mhz : in std_logic;
        rst : in std_logic;

        -- Debug outputs (LEDs)
        debug_led : out std_logic_vector(4 downto 0);

        -- Real Intel 8008 CPU Interface (18-pin DIP)
        -- Data/Address Bus (multiplexed, bidirectional)
        cpu_data : inout std_logic_vector(7 downto 0);

        -- CPU Control Inputs
        cpu_phi1 : out std_logic;      -- Clock phase 1
        cpu_phi2 : out std_logic;      -- Clock phase 2
        cpu_ready : out std_logic;     -- Memory ready signal
        cpu_int : out std_logic;       -- Interrupt request

        -- CPU Status Outputs
        cpu_s0 : in std_logic;         -- State bit 0
        cpu_s1 : in std_logic;         -- State bit 1
        cpu_s2 : in std_logic;         -- State bit 2
        cpu_sync : in std_logic        -- Sync signal
    );
end sim8_01_top;

architecture rtl of sim8_01_top is
    -- Component: Phase Clock Generator
    component phase_clocks is
        port(
            clk_in : in std_logic;
            reset : in std_logic;
            phi1 : out std_logic;
            phi2 : out std_logic
        );
    end component;

    -- Component: ROM (2K x 8)
    component rom_2kx8 is
        port(
            ADDR : in std_logic_vector(10 downto 0);
            DATA_OUT : out std_logic_vector(7 downto 0);
            CS_N : in std_logic
        );
    end component;

    -- Component: RAM (1K x 8)
    component ram_1kx8 is
        port(
            CLK : in std_logic;
            ADDR : in std_logic_vector(9 downto 0);
            DATA_IN : in std_logic_vector(7 downto 0);
            DATA_OUT : out std_logic_vector(7 downto 0);
            CS_N : in std_logic;
            RW_N : in std_logic;
            DEBUG_BYTE_0 : out std_logic_vector(7 downto 0)
        );
    end component;

    -- Internal signals
    signal phi1_int, phi2_int : std_logic;
    signal reset_n : std_logic;

    -- Address latches (demultiplex from data bus)
    signal addr_low : std_logic_vector(7 downto 0);  -- Lower 8 bits
    signal addr_high : std_logic_vector(5 downto 0); -- Upper 6 bits (only)
    signal addr_full : std_logic_vector(13 downto 0); -- Complete 14-bit address

    -- Cycle control bits (from T2 state)
    signal cycle_type : std_logic_vector(1 downto 0); -- D7:D6 during T2

    -- State machine for address capture
    type state_type is (T1, T2, WAIT_STATE, T3, T4, T5, STOPPED);
    signal current_state : state_type;

    -- Memory interface
    signal rom_data : std_logic_vector(7 downto 0);
    signal ram_data : std_logic_vector(7 downto 0);
    signal rom_cs_n : std_logic;
    signal ram_cs_n : std_logic;
    signal ram_rw_n : std_logic;

    -- Data bus control
    signal data_out_enable : std_logic;
    signal data_to_cpu : std_logic_vector(7 downto 0);

begin
    -- Invert reset for active-low components
    reset_n <= not rst;

    -- Instantiate phase clock generator
    clk_gen: phase_clocks port map(
        clk_in => clk_100mhz,
        reset => rst,
        phi1 => phi1_int,
        phi2 => phi2_int
    );

    -- Drive CPU clocks
    cpu_phi1 <= phi1_int;
    cpu_phi2 <= phi2_int;

    -- Drive CPU control signals
    cpu_ready <= '1';  -- Always ready (can implement wait states later)
    cpu_int <= '0';    -- No interrupts for now

    -- State machine to decode CPU cycle and capture addresses
    -- The 8008 outputs address on data bus during T1 and T2
    process(phi2_int, rst)
    begin
        if rst = '1' then
            current_state <= T1;
            addr_low <= (others => '0');
            addr_high <= (others => '0');
            cycle_type <= (others => '0');
        elsif rising_edge(phi2_int) then
            case current_state is
                when T1 =>
                    -- Capture lower 8 bits of address from data bus
                    -- (CPU drives this during T1 with SYNC high)
                    if cpu_sync = '1' then
                        addr_low <= cpu_data;
                        current_state <= T2;
                    end if;

                when T2 =>
                    -- Capture upper 6 bits of address (D5:D0)
                    -- and cycle type (D7:D6) from data bus
                    addr_high <= cpu_data(5 downto 0);
                    cycle_type <= cpu_data(7 downto 6);

                    -- Check READY signal
                    if cpu_ready = '1' then
                        current_state <= T3;
                    else
                        current_state <= WAIT_STATE;
                    end if;

                when WAIT_STATE =>
                    -- Wait for memory to be ready
                    if cpu_ready = '1' then
                        current_state <= T3;
                    end if;

                when T3 =>
                    -- Data transfer state
                    -- Check state outputs to determine next state
                    if cpu_s2 = '1' and cpu_s1 = '1' and cpu_s0 = '0' then
                        -- STOPPED state
                        current_state <= STOPPED;
                    elsif cpu_sync = '1' then
                        -- New cycle starting
                        current_state <= T1;
                    else
                        current_state <= T4;
                    end if;

                when T4 =>
                    if cpu_sync = '1' then
                        current_state <= T1;
                    else
                        current_state <= T5;
                    end if;

                when T5 =>
                    if cpu_sync = '1' then
                        current_state <= T1;
                    else
                        -- Some instructions skip T4/T5
                        current_state <= T1;
                    end if;

                when STOPPED =>
                    -- Remain stopped until interrupt
                    if cpu_int = '1' then
                        current_state <= T1;
                    end if;

            end case;
        end if;
    end process;

    -- Construct full 14-bit address
    addr_full <= addr_high & addr_low;

    -- Address decoding for memory
    -- ROM: 0x0000 - 0x07FF (2K) - responds to PCI (instruction fetch) and PCR (data read)
    -- RAM: 0x0800 - 0x0BFF (1K) - responds to PCR (data read) and PCC (data write)
    --
    -- cycle_type: 00=PCI(fetch), 01=PCR(read), 10=PCC(write), 11=PCW(I/O)
    rom_cs_n <= '0' when (addr_full(13 downto 11) = "000" and
                          cycle_type(1) = '0') -- PCI or PCR cycles
                    else '1';

    -- RAM chip select: activate for PCR (read) or PCC (write) cycles in RAM address range
    ram_cs_n <= '0' when (addr_full(13 downto 10) = "0010" and  -- 0x0800-0x0BFF
                          (cycle_type = "01" or cycle_type = "10") and  -- PCR or PCC
                          current_state = T3)  -- Only during T3 (data transfer state)
                    else '1';

    -- RAM Read/Write control: Write=0 when PCC, Read=1 otherwise
    ram_rw_n <= '0' when (cycle_type = "10") else '1'; -- Write when PCC

    -- Instantiate ROM
    rom: rom_2kx8 port map(
        ADDR => addr_full(10 downto 0),
        DATA_OUT => rom_data,
        CS_N => rom_cs_n
    );

    -- Instantiate RAM
    ram: ram_1kx8 port map(
        CLK => phi1_int,
        ADDR => addr_full(9 downto 0),
        DATA_IN => cpu_data,
        DATA_OUT => ram_data,
        CS_N => ram_cs_n,
        RW_N => ram_rw_n,
        DEBUG_BYTE_0 => open  -- Not used in silicon interface
    );

    -- Data bus multiplexer (drive CPU data bus during T3 reads)
    data_to_cpu <= rom_data when rom_cs_n = '0' else
                   ram_data when ram_cs_n = '0' else
                   (others => '0');

    -- Drive data bus only during T3 state for read cycles
    data_out_enable <= '1' when (current_state = T3 and
                                 cycle_type(1) = '0') -- Read cycles (PCI/PCR)
                           else '0';

    cpu_data <= data_to_cpu when data_out_enable = '1' else (others => 'Z');

    -- Debug LEDs
    debug_led(0) <= phi1_int;
    debug_led(1) <= phi2_int;
    -- Check CPU state bits for STOPPED state (S2=1, S1=1, S0=0)
    debug_led(2) <= '1' when (cpu_s2 = '1' and cpu_s1 = '1' and cpu_s0 = '0') else '0';
    debug_led(3) <= '1' when cycle_type(1) = '0' else '0'; -- Read indicator
    debug_led(4) <= '1' when cycle_type = "11" else '0';   -- Write indicator

end rtl;