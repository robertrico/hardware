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
    generic (
        -- Clock frequency configuration
        CLK_FREQ_MHZ : integer := 100;      -- FPGA input clock (100 MHz on ECP5 Versa)
        CPU_FREQ_KHZ : integer := 500       -- Target 8008 clock frequency (500 kHz or 800 kHz)
    );
    port (
        -- FPGA Board Inputs
        clk : in std_logic;                 -- 100 MHz FPGA clock
        rst : in std_logic;                 -- Reset (active high)

        -- Intel 8008 CPU Interface - Inputs from 8008
        cpu_d     : inout std_logic_vector(7 downto 0);  -- 8008 data bus (bidirectional)
        cpu_s0    : in std_logic;           -- State bit 0
        cpu_s1    : in std_logic;           -- State bit 1
        cpu_s2    : in std_logic;           -- State bit 2
        cpu_sync  : in std_logic;           -- Sync signal (high during T1/T2)

        -- Intel 8008 CPU Interface - Outputs to 8008
        cpu_phi1      : out std_logic;      -- Phase 1 clock
        cpu_phi2      : out std_logic;      -- Phase 2 clock (non-overlapping with phi1)
        cpu_ready     : out std_logic;      -- Ready signal (for wait states)
        cpu_interrupt : out std_logic;      -- Interrupt request

        -- Memory Interface (to external RAM/ROM or FPGA block RAM)
        mem_addr   : out std_logic_vector(13 downto 0);  -- 14-bit address bus
        mem_data   : inout std_logic_vector(7 downto 0); -- 8-bit data bus
        mem_read_n : out std_logic;         -- Memory read enable (active low)
        mem_write_n: out std_logic;         -- Memory write enable (active low)
        rom_cs_n   : out std_logic;         -- ROM chip select (active low)
        ram_cs_n   : out std_logic;         -- RAM chip select (active low)

        -- I/O Interface
        io_addr    : out std_logic_vector(4 downto 0);   -- 5-bit I/O address (32 ports)
        io_data    : inout std_logic_vector(7 downto 0); -- I/O data bus
        io_read_n  : out std_logic;         -- I/O read enable (active low)
        io_write_n : out std_logic;         -- I/O write enable (active low)

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
    -- Temporary Assignments (until modules are implemented)
    --===========================================

    -- Default READY to active (no wait states for now)
    cpu_ready <= '1';

    -- No interrupts for now
    cpu_interrupt <= '0';

    -- Disable memory until controller is implemented
    mem_addr <= (others => '0');
    mem_read_n <= '1';
    mem_write_n <= '1';
    rom_cs_n <= '1';
    ram_cs_n <= '1';

    -- Disable I/O until controller is implemented
    io_addr <= (others => '0');
    io_read_n <= '1';
    io_write_n <= '1';

    -- Tri-state buses (set to high-Z until controllers are implemented)
    cpu_d <= (others => 'Z');
    mem_data <= (others => 'Z');
    io_data <= (others => 'Z');

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
