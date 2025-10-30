-------------------------------------------------------------------------------
-- Intel SIM8-01 Recreation - Softcore Testing Top Level
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Robert Rico
--
-- Top-level design using the i8008 soft processor core for testing and
-- verification of glue logic before connecting to real vintage hardware.
--
-- This module integrates:
--   - i8008 soft processor core (VHDL implementation)
--   - Memory subsystem (2K ROM + 1K RAM)
--   - Two-phase clock generation
--   - Support circuitry
--
-- Based on Intel SIM8-01 reference design with adaptations for FPGA.
--
-- License: MIT (see LICENSE.txt)
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sim8_01_top is
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
        debug_reg_l      : out std_logic_vector(7 downto 0)
    );
end sim8_01_top;

architecture rtl of sim8_01_top is

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

    -- i8008 CPU softcore (for testing before connecting real chip)
    component i8008_cpu is
        port(
            clk : in std_logic;
            reset_n : in std_logic;
            mem_address : out std_logic_vector(13 downto 0);
            mem_data_in : out std_logic_vector(7 downto 0);
            mem_data_out : in std_logic_vector(7 downto 0);
            mem_read : out std_logic;
            mem_write : out std_logic;
            halted : out std_logic
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
    signal cpu_clk : std_logic;
    signal cpu_reset_n : std_logic;
    signal cpu_halted : std_logic;

    -- Memory bus signals
    signal mem_address : std_logic_vector(13 downto 0);
    signal mem_data_in : std_logic_vector(7 downto 0);
    signal mem_data_out : std_logic_vector(7 downto 0);
    signal mem_read : std_logic;
    signal mem_write : std_logic;

    -- ROM/RAM signals
    signal rom_cs_n : std_logic;
    signal ram_cs_n : std_logic;
    signal rom_data : std_logic_vector(7 downto 0);
    signal ram_data : std_logic_vector(7 downto 0);

begin

    --===========================================
    -- Module Instantiations
    --===========================================

    -- Phase Clock Generator
    -- Generates two-phase non-overlapping clocks (φ1 and φ2) for the 8008
    phase_clock_gen: phase_clocks
        port map (
            clk_in => clk,
            reset  => rst,
            phi1   => phi1_int,
            phi2   => phi2_int
        );

    -- Connect phase clocks to CPU
    cpu_phi1 <= phi1_int;
    cpu_phi2 <= phi2_int;

    -- Use phi1 as CPU clock for now (can be adjusted)
    cpu_clk <= phi1_int;
    cpu_reset_n <= not rst;

    -- Address Decoding
    -- ROM: 0x0000 - 0x07FF (0-2047)
    -- RAM: 0x0800 - 0x0BFF (2048-3071)
    rom_cs_n <= '0' when (mem_address(13 downto 11) = "000" and mem_read = '1') else '1';
    ram_cs_n <= '0' when (mem_address(13 downto 11) = "001" and (mem_read = '1' or mem_write = '1')) else '1';

    -- Memory data output mux
    mem_data_out <= rom_data when rom_cs_n = '0' else
                    ram_data when ram_cs_n = '0' else
                    (others => '0');

    -- i8008 CPU (softcore for testing)
    cpu: i8008_cpu
        port map(
            clk => cpu_clk,
            reset_n => cpu_reset_n,
            mem_address => mem_address,
            mem_data_in => mem_data_in,
            mem_data_out => mem_data_out,
            mem_read => mem_read,
            mem_write => mem_write,
            halted => cpu_halted
        );

    -- ROM (2K x 8) - Program storage
    rom: rom_2kx8
        port map(
            ADDR => mem_address(10 downto 0),
            DATA_OUT => rom_data,
            CS_N => rom_cs_n
        );

    -- RAM (1K x 8) - Working memory
    ram: ram_1kx8
        port map(
            CLK => cpu_clk,
            ADDR => mem_address(9 downto 0),
            DATA_IN => mem_data_in,
            DATA_OUT => ram_data,
            RW_N => not mem_write,
            CS_N => ram_cs_n,
            DEBUG_BYTE_0 => debug_ram_byte_0
        );

    -- TODO: Instantiate additional modules as they are developed
    --
    -- state_dec: state_decoder
    --     port map (
    --         s0 => cpu_s0,
    --         s1 => cpu_s1,
    --         s2 => cpu_s2,
    --         ...
    --     );
    --
    -- addr_latch: address_latch
    --     port map (
    --         clk      => clk,
    --         rst      => rst,
    --         cpu_d    => cpu_d,
    --         cpu_sync => cpu_sync,
    --         addr_out => latched_addr,
    --         ...
    --     );
    --
    -- mem_ctrl: memory_controller
    --     port map (
    --         clk        => clk,
    --         rst        => rst,
    --         addr       => latched_addr,
    --         mem_addr   => mem_addr,
    --         mem_data   => mem_data,
    --         mem_read_n => mem_read_n,
    --         mem_write_n=> mem_write_n,
    --         rom_cs_n   => rom_cs_n,
    --         ram_cs_n   => ram_cs_n,
    --         ...
    --     );
    --
    -- io_ctrl: io_controller
    --     port map (
    --         clk       => clk,
    --         rst       => rst,
    --         io_addr   => io_addr,
    --         io_data   => io_data,
    --         io_read_n => io_read_n,
    --         io_write_n=> io_write_n,
    --         ...
    --     );

    --===========================================
    -- Debug Outputs
    --===========================================

    -- Display status on LEDs for debugging
    -- LED[0] = phi1 clock
    -- LED[1] = phi2 clock
    -- LED[2] = CPU halted
    -- LED[3] = mem_read
    -- LED[4] = mem_write
    -- LED[7:5] = reserved
    debug_led(0) <= phi1_int;
    debug_led(1) <= phi2_int;
    debug_led(2) <= cpu_halted;
    debug_led(3) <= mem_read;
    debug_led(4) <= mem_write;
    debug_led(7 downto 5) <= (others => '0');

    -- Debug outputs for testbench
    debug_mem_addr <= mem_address;
    debug_mem_data <= mem_data_in;

    -- Note: LEDs on ECP5 Versa are active-low, but this is handled in constraints

end rtl;
