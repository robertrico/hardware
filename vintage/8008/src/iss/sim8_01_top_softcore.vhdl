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
        debug_reg_l      : out std_logic_vector(7 downto 0);
        debug_rom_cs_n   : out std_logic;
        debug_ram_cs_n   : out std_logic;
        debug_sync       : out std_logic  -- SYNC signal for observation
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

    -- i8008 CPU softcore (now with real 8008 interface)
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

    -- Address demultiplex (captured from bus during T1/T2)
    signal addr_low : std_logic_vector(7 downto 0);
    signal addr_high : std_logic_vector(5 downto 0);
    signal addr_full : std_logic_vector(13 downto 0);

    -- Cycle control
    signal cycle_type : std_logic_vector(1 downto 0);  -- From D7:D6 during T2
    signal is_write_cycle : std_logic;
    signal is_read_cycle : std_logic;
    signal was_sync : std_logic := '0';  -- Debug: track SYNC capture state

    -- Timing state decode
    type timing_state_t is (T1, T1I, T2, TWAIT, T3, T4, T5);
    signal timing_state : timing_state_t;

    -- ROM/RAM signals
    signal rom_cs_n : std_logic;
    signal ram_cs_n : std_logic;
    signal rom_data : std_logic_vector(7 downto 0);
    signal ram_data : std_logic_vector(7 downto 0);
    signal mem_data : std_logic_vector(7 downto 0);

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

    -- Connect phase clocks
    cpu_phi1 <= phi1_int;
    cpu_phi2 <= phi2_int;
    cpu_reset_n <= not rst;

    -- Tie-off control signals (for now - can be connected to switches)
    cpu_READY <= '1';  -- Always ready (no wait states)
    cpu_INT <= '0';    -- No interrupts

    --===========================================
    -- Timing State Decoder (from S0/S1/S2)
    --===========================================
    process(cpu_S0, cpu_S1, cpu_S2)
        variable state_bits : std_logic_vector(2 downto 0);
    begin
        state_bits := cpu_S2 & cpu_S1 & cpu_S0;
        case state_bits is
            when "000" => timing_state <= T1;
            when "001" => timing_state <= T1I;
            when "010" => timing_state <= T2;
            when "011" => timing_state <= TWAIT;
            when "100" => timing_state <= T3;
            when "110" => timing_state <= T4;
            when "111" => timing_state <= T5;
            when others => timing_state <= T1;
        end case;
    end process;

    --===========================================
    -- Address Demultiplexing Logic
    --===========================================
    -- Capture address from data bus during T1 and T2 states
    -- Real 8008 compatible: Handle free-running SYNC pulses
    -- Latch address on SYNC rising edge, hold until next SYNC rising edge

    process(phi2_int, cpu_reset_n)
        variable prev_sync : std_logic := '0';
        type latch_state_t is (IDLE, WAIT_T2, HOLD_CYCLE);
        variable latch_state : latch_state_t := IDLE;
        variable sync_edge_count : integer range 0 to 7 := 0;
    begin
        if cpu_reset_n = '0' then
            addr_low <= (others => '0');
            addr_high <= (others => '0');
            cycle_type <= (others => '0');
            was_sync <= '0';
            prev_sync := '0';
            latch_state := IDLE;
            sync_edge_count := 0;
        elsif rising_edge(phi2_int) then
            -- Sample on phi2 rising edge when bus data is stable
            -- Real 8008: SYNC goes high during phi2, address is valid throughout phi1+phi2

            -- State machine to latch address and hold it stable through the cycle
            -- With corrected SYNC timing (toggles every clock period), we need to:
            -- - Latch addr_low on first SYNC rising edge (T1)
            -- - Latch addr_high+cycle_type on next SYNC falling edge (T2)
            -- - Ignore next 3 SYNC rising edges (T3, T4, T5)
            -- - Accept 4th SYNC rising edge as new cycle's T1
            case latch_state is
                when IDLE =>
                    -- Wait for SYNC rising edge to start new cycle
                    if cpu_SYNC = '1' and prev_sync = '0' then
                        -- SYNC rising edge: Latch lower address byte, enter WAIT_T2
                        addr_low <= cpu_data_bus;
                        latch_state := WAIT_T2;
                        report "T1: Captured addr_low=0x" & to_hstring(cpu_data_bus);
                    end if;

                when WAIT_T2 =>
                    -- Wait for SYNC falling edge (T2 state)
                    if cpu_SYNC = '0' and prev_sync = '1' then
                        -- SYNC falling edge: T2 state, latch upper address + cycle type
                        addr_high <= cpu_data_bus(5 downto 0);
                        cycle_type <= cpu_data_bus(7 downto 6);
                        latch_state := HOLD_CYCLE;  -- Hold values through T3/T4/T5
                        sync_edge_count := 0;  -- Reset counter
                        report "T2: Captured addr_high=0x" & to_hstring(cpu_data_bus(5 downto 0)) & " cycle_type=" & to_string(cpu_data_bus(7 downto 6)) & " full_addr=0x" & to_hstring(cpu_data_bus(5 downto 0) & addr_low);
                    end if;

                when HOLD_CYCLE =>
                    -- Hold latched values stable through T3/T4/T5
                    -- Count SYNC rising edges and start new cycle on the 4th one
                    if cpu_SYNC = '1' and prev_sync = '0' then
                        sync_edge_count := sync_edge_count + 1;
                        report "HOLD_CYCLE: SYNC rising edge #" & integer'image(sync_edge_count);

                        if sync_edge_count >= 3 then
                            -- 4th SYNC rising edge: new cycle's T1
                            addr_low <= cpu_data_bus;
                            latch_state := WAIT_T2;
                            sync_edge_count := 0;
                            report "T1 (new cycle after hold): Captured addr_low=0x" & to_hstring(cpu_data_bus);
                        end if;
                    end if;
            end case;

            -- Track SYNC for edge detection on next phi2
            prev_sync := cpu_SYNC;
        end if;
    end process;

    -- Assemble full 14-bit address
    addr_full <= addr_high & addr_low;

    -- Decode cycle type: "10" = write, anything else = read
    is_read_cycle <= '1' when cycle_type /= "10" else '0';
    is_write_cycle <= '1' when cycle_type = "10" else '0';

    --===========================================
    -- Address Decoding for ROM/RAM
    --===========================================
    -- ROM: 0x0000 - 0x07FF (0-2047)
    -- RAM: 0x0800 - 0x0BFF (2048-3071)
    -- Enable ROM for read cycles in ROM address range
    -- Enable RAM for read or write cycles in RAM address range
    rom_cs_n <= '0' when (addr_full(13 downto 11) = "000" and is_read_cycle = '1') else '1';
    ram_cs_n <= '0' when (addr_full(13 downto 11) = "001") else '1';

    -- Memory data output mux
    process(rom_cs_n, ram_cs_n, rom_data, ram_data, addr_full)
    begin
        if rom_cs_n = '0' then
            mem_data <= rom_data;
            report "MEM MUX: Selecting ROM data=0x" & to_hstring(rom_data) & " for addr=0x" & to_hstring(addr_full);
        elsif ram_cs_n = '0' then
            mem_data <= ram_data;
            report "MEM MUX: Selecting RAM data=0x" & to_hstring(ram_data) & " for addr=0x" & to_hstring(addr_full);
        else
            mem_data <= (others => '0');
            report "MEM MUX: No chip selected, returning 0x00 for addr=0x" & to_hstring(addr_full);
        end if;
    end process;

    -- Drive data bus with memory data during T3 read cycles only
    -- Use S0/S1/S2 directly: T3 = 100
    cpu_data_bus <= mem_data when (cpu_S2 = '1' and cpu_S1 = '0' and cpu_S0 = '0' and is_read_cycle = '1') else (others => 'Z');

    --===========================================
    -- i8008 CPU (softcore with real 8008 interface)
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
            DATA_IN => cpu_data_bus,  -- Data from CPU during writes
            DATA_OUT => ram_data,
            RW_N => not is_write_cycle,
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
    -- LED[3] = was_sync (for debug)
    -- LED[4] = is_write_cycle
    -- LED[5] = is_read_cycle
    -- LED[7:6] = cycle_type
    debug_led(0) <= phi1_int;
    debug_led(1) <= phi2_int;
    debug_led(2) <= cpu_halted;
    debug_led(3) <= was_sync;  -- Changed from cpu_SYNC for debugging
    debug_led(4) <= is_write_cycle;
    debug_led(5) <= is_read_cycle;
    debug_led(7 downto 6) <= cycle_type;

    -- Debug outputs for testbench
    debug_mem_addr <= addr_full;
    debug_mem_data <= cpu_data_bus;
    debug_rom_cs_n <= rom_cs_n;
    debug_ram_cs_n <= ram_cs_n;
    debug_sync <= cpu_SYNC;

    -- Note: LEDs on ECP5 Versa are active-low, but this is handled in constraints

end rtl;
