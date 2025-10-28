-- SIM8-01 System Top Level
-- Complete glue logic system for Intel 8008 microprocessor
-- Based on the SIM8-01 reference design from Intel 8008 User Manual
--
-- This module integrates all support circuitry needed to interface with
-- a real Intel 8008 chip (not a CPU implementation - we have real silicon!)

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
        sw         : in std_logic_vector(7 downto 1)     -- DIP switches for config
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

    -- TODO: Add more component declarations as modules are developed:
    -- component state_decoder is ... end component;
    -- component timing_generator is ... end component;
    -- component address_latch is ... end component;
    -- component data_bus_buffer is ... end component;
    -- component memory_controller is ... end component;
    -- component io_controller is ... end component;
    -- component interrupt_logic is ... end component;
    -- component ready_generator is ... end component;

    --===========================================
    -- Internal Signals
    --===========================================

    -- Phase clock signals
    signal phi1_int   : std_logic;
    signal phi2_int   : std_logic;

    -- TODO: Add internal signals for module interconnections
    -- signal latched_addr : std_logic_vector(13 downto 0);
    -- signal mem_cycle    : std_logic;
    -- signal io_cycle     : std_logic;
    -- signal data_read    : std_logic;
    -- signal data_write   : std_logic;

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

    -- Display clock status on LEDs for debugging
    -- LED[0] = phi1 (will blink at CPU frequency)
    -- LED[1] = phi2 (will blink at CPU frequency, opposite phase)
    -- LED[7:2] = reserved for future status
    debug_led(0) <= phi1_int;
    debug_led(1) <= phi2_int;
    debug_led(7 downto 2) <= (others => '0');

    -- Note: LEDs on ECP5 Versa are active-low, but this is handled in constraints

end rtl;
