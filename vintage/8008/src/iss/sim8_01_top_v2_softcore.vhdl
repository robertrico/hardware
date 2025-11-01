-------------------------------------------------------------------------------
-- Intel SIM8-01 Recreation - Softcore V2 with Proper Glue Logic
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Robert Rico
--
-- Top-level design using proper 8008 glue logic components:
--   - Intel 8212 transparent address latches
--   - Timing controller for state tracking
--   - Handles free-running SYNC pulses (continuous T1-T5 cycles)
--
-- This module integrates:
--   - i8008 soft processor core (VHDL implementation)
--   - Memory subsystem (2K ROM + 1K RAM)
--   - Two-phase clock generation
--   - Proper hardware-modeled glue logic
--
-- Based on Intel SIM8-01 reference design with proper 8212 latches.
--
-- License: MIT (see LICENSE.txt)
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sim8_01_top_v2_softcore is
    port (
        -- FPGA Board Inputs
        clk : in std_logic;                 -- 100 MHz FPGA clock
        rst : in std_logic;                 -- Reset (active high)

        -- Phase clock outputs (for testing)
        cpu_phi1      : out std_logic;      -- Phase 1 clock
        cpu_phi2      : out std_logic;      -- Phase 2 clock (non-overlapping with phi1)

        -- Debug/Status outputs
        debug_led  : out std_logic_vector(7 downto 0);   -- LED outputs for debugging
        sw         : in std_logic_vector(7 downto 1);    -- DIP switches for config

        -- Testbench debug outputs
        debug_ram_byte_0 : out std_logic_vector(7 downto 0);
        debug_mem_addr   : out std_logic_vector(13 downto 0);
        debug_mem_data   : out std_logic_vector(7 downto 0);
        debug_reg_h      : out std_logic_vector(7 downto 0);
        debug_reg_l      : out std_logic_vector(7 downto 0);
        debug_rom_cs_n   : out std_logic;
        debug_ram_cs_n   : out std_logic
    );
end sim8_01_top_v2_softcore;

architecture rtl of sim8_01_top_v2_softcore is

    --===========================================
    -- Component Declarations
    --===========================================

    -- Phase clock generator (φ1 and φ2 non-overlapping clocks)
    component phase_clocks is
        port (
            clk_in : in  std_logic;
            reset  : in  std_logic;
            phi1   : out std_logic;
            phi2   : out std_logic
        );
    end component;

    -- i8008 CPU softcore (with free-running T5 cycles)
    component i8008_cpu is
        port(
            phi1 : in std_logic;
            phi2 : in std_logic;
            reset_n : in std_logic;
            data_bus : inout std_logic_vector(7 downto 0);
            S0 : out std_logic;
            S1 : out std_logic;
            S2 : out std_logic;
            SYNC : out std_logic;
            READY : in std_logic;
            INT : in std_logic;
            halted : out std_logic;
            debug_reg_h : out std_logic_vector(7 downto 0);
            debug_reg_l : out std_logic_vector(7 downto 0)
        );
    end component;

    -- Intel 8212 transparent address latch
    component addr_latch_8212 is
        port(
            DI : in std_logic_vector(7 downto 0);
            STB : in std_logic;
            DO : out std_logic_vector(7 downto 0)
        );
    end component;

    -- 8008 timing controller (state machine)
    component timing_controller_8008 is
        port(
            phi2 : in std_logic;
            reset_n : in std_logic;
            SYNC : in std_logic;
            S0 : in std_logic;
            S1 : in std_logic;
            S2 : in std_logic;
            state_T1 : out std_logic;
            state_T2 : out std_logic;
            state_T3 : out std_logic;
            latch_low_enable : out std_logic;
            latch_high_enable : out std_logic
        );
    end component;

    -- ROM: 2K x 8
    component rom_2kx8 is
        port(
            ADDR : in std_logic_vector(10 downto 0);
            DATA_OUT : out std_logic_vector(7 downto 0);
            CS_N : in std_logic
        );
    end component;

    -- RAM: 1K x 8
    component ram_1kx8 is
        port(
            CLK : in std_logic;
            ADDR : in std_logic_vector(9 downto 0);
            DATA_IN : in std_logic_vector(7 downto 0);
            DATA_OUT : out std_logic_vector(7 downto 0);
            RW_N : in std_logic;
            CS_N : in std_logic;
            DEBUG_BYTE_0 : out std_logic_vector(7 downto 0)
        );
    end component;

    --===========================================
    -- Internal Signals
    --===========================================

    -- Phase clock signals
    signal phi1_int   : std_logic;
    signal phi2_int   : std_logic;

    -- CPU signals
    signal cpu_reset_n : std_logic;
    signal cpu_halted : std_logic;
    signal cpu_data_bus : std_logic_vector(7 downto 0);

    -- CPU state signals
    signal cpu_S0 : std_logic;
    signal cpu_S1 : std_logic;
    signal cpu_S2 : std_logic;
    signal cpu_SYNC : std_logic;
    signal cpu_READY : std_logic;
    signal cpu_INT : std_logic;

    -- Timing controller outputs
    signal state_T1 : std_logic;
    signal state_T2 : std_logic;
    signal state_T3 : std_logic;
    signal latch_low_enable : std_logic;
    signal latch_high_enable : std_logic;

    -- Address latches (8212 outputs)
    signal addr_low_latched : std_logic_vector(7 downto 0);
    signal addr_high_latched : std_logic_vector(7 downto 0);  -- Contains upper 6 bits + cycle_type[1:0]

    -- Address and control signals
    signal addr_full : std_logic_vector(13 downto 0);
    signal cycle_type : std_logic_vector(1 downto 0);

    -- ROM/RAM signals
    signal rom_cs_n : std_logic;
    signal ram_cs_n : std_logic;
    signal ram_rw_n : std_logic;
    signal rom_data : std_logic_vector(7 downto 0);
    signal ram_data : std_logic_vector(7 downto 0);
    signal mem_data : std_logic_vector(7 downto 0);

begin

    --===========================================
    -- Module Instantiations
    --===========================================

    -- Phase Clock Generator
    phase_clock_gen: phase_clocks
        port map (
            clk_in => clk,
            reset  => rst,
            phi1   => phi1_int,
            phi2   => phi2_int
        );

    cpu_phi1 <= phi1_int;
    cpu_phi2 <= phi2_int;
    cpu_reset_n <= not rst;

    -- Tie-off control signals
    cpu_READY <= '1';  -- Always ready (no wait states)
    cpu_INT <= '0';    -- No interrupts

    --===========================================
    -- i8008 CPU (softcore with free-running T5)
    --===========================================
    cpu: i8008_cpu
        port map(
            phi1 => phi1_int,
            phi2 => phi2_int,
            reset_n => cpu_reset_n,
            data_bus => cpu_data_bus,
            S0 => cpu_S0,
            S1 => cpu_S1,
            S2 => cpu_S2,
            SYNC => cpu_SYNC,
            READY => cpu_READY,
            INT => cpu_INT,
            halted => cpu_halted,
            debug_reg_h => debug_reg_h,
            debug_reg_l => debug_reg_l
        );

    --===========================================
    -- Timing Controller (State Machine)
    --===========================================
    timing_ctrl: timing_controller_8008
        port map(
            phi1 => phi1_int,  -- Changed from phi2 to phi1 to sync with CPU
            reset_n => cpu_reset_n,
            SYNC => cpu_SYNC,
            S0 => cpu_S0,
            S1 => cpu_S1,
            S2 => cpu_S2,
            state_T1 => state_T1,
            state_T2 => state_T2,
            state_T3 => state_T3,
            latch_low_enable => latch_low_enable,
            latch_high_enable => latch_high_enable
        );

    --===========================================
    -- Address Latching (simplified for FPGA)
    --===========================================
    -- Latch addresses on phi1 falling edge during appropriate states
    -- phi1 falling edge is in the middle of each state period, ensuring stability

    process(phi1_int, cpu_reset_n)
    begin
        if cpu_reset_n = '0' then
            addr_low_latched <= (others => '0');
            addr_high_latched <= (others => '0');
        elsif falling_edge(phi1_int) then
            -- Latch lower address during T1 (when SYNC=1)
            if cpu_SYNC = '1' then
                addr_low_latched <= cpu_data_bus;
                report "Latched addr_low=0x" & to_hstring(cpu_data_bus) & " during T1";
            end if;

            -- Latch upper address + cycle type during T2 (when SYNC=0 and we're in T2)
            if cpu_SYNC = '0' and state_T2 = '1' then
                addr_high_latched <= cpu_data_bus;
                report "Latched addr_high+cycle=0x" & to_hstring(cpu_data_bus) & " during T2";
            end if;
        end if;
    end process;

    -- Extract address and cycle type from latched data
    addr_full <= addr_high_latched(5 downto 0) & addr_low_latched;
    cycle_type <= addr_high_latched(7 downto 6);

    --===========================================
    -- Memory Address Decoding
    --===========================================
    -- ROM: 0x0000 - 0x07FF (0-2047) - PCI (00) or PCR (01) cycles only
    -- RAM: 0x0800 - 0x0BFF (2048-3071) - PCR (01) or PCC (10) cycles
    --
    -- CRITICAL: Only activate during T3 state to prevent spurious accesses
    -- during idle free-running cycles

    -- ROM chip select: activate for PCI or PCR cycles in ROM range during T3
    rom_cs_n <= '0' when (addr_full(13 downto 11) = "000" and  -- ROM address range
                          (cycle_type = "00" or cycle_type = "01") and  -- PCI or PCR
                          state_T3 = '1')  -- Only during T3 (data transfer state)
                else '1';

    -- RAM chip select: activate for PCR or PCC cycles in RAM range during T3
    ram_cs_n <= '0' when (addr_full(13 downto 10) = "0010" and  -- RAM address range 0x0800-0x0BFF
                          (cycle_type = "01" or cycle_type = "10") and  -- PCR or PCC
                          state_T3 = '1')  -- Only during T3 (data transfer state)
                else '1';

    -- RAM Read/Write control: Write=0 when PCC, Read=1 otherwise
    ram_rw_n <= '0' when (cycle_type = "10") else '1';

    --===========================================
    -- ROM (2K x 8) - Program storage
    --===========================================
    rom: rom_2kx8
        port map(
            ADDR => addr_full(10 downto 0),
            DATA_OUT => rom_data,
            CS_N => rom_cs_n
        );

    --===========================================
    -- RAM (1K x 8) - Working memory
    --===========================================
    ram: ram_1kx8
        port map(
            CLK => phi1_int,
            ADDR => addr_full(9 downto 0),
            DATA_IN => cpu_data_bus,
            DATA_OUT => ram_data,
            RW_N => ram_rw_n,
            CS_N => ram_cs_n,
            DEBUG_BYTE_0 => debug_ram_byte_0
        );

    --===========================================
    -- Data Bus Multiplexer
    --===========================================
    -- Drive data bus with memory data during T3 read cycles
    -- For writes, CPU drives the bus

    process(rom_cs_n, ram_cs_n, rom_data, ram_data, cycle_type, state_T3)
    begin
        if rom_cs_n = '0' and state_T3 = '1' then
            mem_data <= rom_data;
        elsif ram_cs_n = '0' and state_T3 = '1' and cycle_type = "01" then
            mem_data <= ram_data;
        else
            mem_data <= (others => 'Z');
        end if;
    end process;

    -- Drive CPU data bus during read cycles in T3
    cpu_data_bus <= mem_data when (state_T3 = '1' and cycle_type /= "10") else (others => 'Z');

    --===========================================
    -- Debug Outputs
    --===========================================

    -- Display status on LEDs for debugging
    debug_led(0) <= phi1_int;
    debug_led(1) <= phi2_int;
    debug_led(2) <= cpu_halted;
    debug_led(3) <= state_T1;
    debug_led(4) <= state_T2;
    debug_led(5) <= state_T3;
    debug_led(7 downto 6) <= cycle_type;

    -- Debug outputs for testbench
    debug_mem_addr <= addr_full;
    debug_mem_data <= cpu_data_bus;
    debug_rom_cs_n <= rom_cs_n;
    debug_ram_cs_n <= ram_cs_n;

end rtl;
