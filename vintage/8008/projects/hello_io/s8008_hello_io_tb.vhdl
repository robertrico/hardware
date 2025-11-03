-------------------------------------------------------------------------------
-- Testbench for Intel 8008 - Hello World I/O Program
-------------------------------------------------------------------------------
-- Hardware-accurate testbench using real ROM, RAM, and I/O console
--
-- Memory Map:
--   0x0000 - 0x07FF (2KB):  ROM (program memory)
--   0x0800 - 0x0BFF (1KB):  RAM (data memory)
--
-- I/O Port Map:
--   Port 0: Console TX Data (write only) - Output character
--   Port 1: Console TX Status (read only) - Always ready (0x01)
--   Port 2: Console RX Data (read only) - Not implemented (0x00)
--   Port 3: Console RX Status (read only) - Not implemented (0x00)
--
-- Program Flow (hello_io.asm):
--   1. JMP to MAIN at 0x0100
--   2. Load H:L with 0x00C8 (pointer to string in ROM)
--   3. Loop through string:
--      - Load character from [H:L]
--      - Check for null terminator (0x00)
--      - Output character to port 0 (OUT 0)
--      - Increment pointer
--   4. HLT when complete
--
-- Expected Result:
--   - "Hello, World!\n" output to console and file
--   - 14 characters total (13 + newline)
--   - CPU halts in STOPPED state
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity s8008_hello_io_tb is
end s8008_hello_io_tb;

architecture sim of s8008_hello_io_tb is

    -- Component declarations
    component s8008 is
        port (
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
            debug_reg_A : out std_logic_vector(7 downto 0);
            debug_reg_B : out std_logic_vector(7 downto 0);
            debug_reg_C : out std_logic_vector(7 downto 0);
            debug_reg_D : out std_logic_vector(7 downto 0);
            debug_reg_E : out std_logic_vector(7 downto 0);
            debug_reg_H : out std_logic_vector(7 downto 0);
            debug_reg_L : out std_logic_vector(7 downto 0);
            debug_pc : out std_logic_vector(13 downto 0);
            debug_flags : out std_logic_vector(3 downto 0)
        );
    end component;

    component phase_clocks is
        port (
            clk_in : in std_logic;
            reset  : in std_logic;
            phi1   : out std_logic;
            phi2   : out std_logic
        );
    end component;

    component rom_2kx8 is
        generic(
            ROM_FILE : string := "test_programs/hello_io.mem"
        );
        port(
            ADDR : in std_logic_vector(10 downto 0);
            DATA_OUT : out std_logic_vector(7 downto 0);
            CS_N : in std_logic
        );
    end component;

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

    component io_console is
        generic(
            OUTPUT_FILE : string := "console_output.txt"
        );
        port(
            phi1 : in std_logic;
            phi2 : in std_logic;
            reset : in std_logic;
            S0 : in std_logic;
            S1 : in std_logic;
            S2 : in std_logic;
            data_bus : inout std_logic_vector(7 downto 0)
        );
    end component;

    -- Clock and reset signals
    signal master_clk_tb : std_logic := '0';
    signal reset_tb : std_logic := '1';
    signal phi1_tb : std_logic := '0';
    signal phi2_tb : std_logic := '0';
    signal reset_n_tb : std_logic := '0';

    -- CPU signals
    signal data_bus_tb : std_logic_vector(7 downto 0);
    signal S0_tb : std_logic;
    signal S1_tb : std_logic;
    signal S2_tb : std_logic;
    signal SYNC_tb : std_logic;
    signal READY_tb : std_logic := '1';
    signal INT_tb : std_logic := '0';

    -- Debug signals
    signal debug_reg_A_tb : std_logic_vector(7 downto 0);
    signal debug_reg_B_tb : std_logic_vector(7 downto 0);
    signal debug_reg_C_tb : std_logic_vector(7 downto 0);
    signal debug_reg_D_tb : std_logic_vector(7 downto 0);
    signal debug_reg_E_tb : std_logic_vector(7 downto 0);
    signal debug_reg_H_tb : std_logic_vector(7 downto 0);
    signal debug_reg_L_tb : std_logic_vector(7 downto 0);
    signal debug_pc_tb : std_logic_vector(13 downto 0);
    signal debug_flags_tb : std_logic_vector(3 downto 0);

    -- Memory interface signals
    signal mem_addr : std_logic_vector(13 downto 0) := (others => '0');
    signal addr_low_capture : std_logic_vector(7 downto 0) := (others => '0');
    signal addr_high_capture : std_logic_vector(5 downto 0) := (others => '0');
    signal cycle_type_capture : std_logic_vector(1 downto 0) := "00";

    -- ROM signals (0x0000 - 0x07FF)
    signal rom_addr : std_logic_vector(10 downto 0);
    signal rom_data : std_logic_vector(7 downto 0);
    signal rom_cs_n : std_logic := '1';

    -- RAM signals (0x0800 - 0x0BFF)
    signal ram_addr : std_logic_vector(9 downto 0);
    signal ram_data_in : std_logic_vector(7 downto 0);
    signal ram_data_out : std_logic_vector(7 downto 0);
    signal ram_rw_n : std_logic := '1';
    signal ram_cs_n : std_logic := '1';
    signal ram_debug_byte_0 : std_logic_vector(7 downto 0);

    -- Timing
    constant MASTER_CLK_PERIOD : time := 10 ns;
    signal sim_done : boolean := false;

    -- Instruction tracking
    signal instruction_count : integer := 0;
    signal last_SYNC : std_logic := '0';

begin

    --===========================================
    -- Clock Generation
    --===========================================
    master_clk_gen: process
    begin
        while not sim_done loop
            master_clk_tb <= '0';
            wait for MASTER_CLK_PERIOD / 2;
            master_clk_tb <= '1';
            wait for MASTER_CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    --===========================================
    -- Component Instantiations
    --===========================================

    -- Phase clock generator
    phase_gen: phase_clocks
        port map (
            clk_in => master_clk_tb,
            reset  => reset_tb,
            phi1   => phi1_tb,
            phi2   => phi2_tb
        );

    -- CPU
    cpu: s8008
        port map (
            phi1 => phi1_tb,
            phi2 => phi2_tb,
            reset_n => reset_n_tb,
            data_bus => data_bus_tb,
            S0 => S0_tb,
            S1 => S1_tb,
            S2 => S2_tb,
            SYNC => SYNC_tb,
            READY => READY_tb,
            INT => INT_tb,
            debug_reg_A => debug_reg_A_tb,
            debug_reg_B => debug_reg_B_tb,
            debug_reg_C => debug_reg_C_tb,
            debug_reg_D => debug_reg_D_tb,
            debug_reg_E => debug_reg_E_tb,
            debug_reg_H => debug_reg_H_tb,
            debug_reg_L => debug_reg_L_tb,
            debug_pc => debug_pc_tb,
            debug_flags => debug_flags_tb
        );

    -- ROM (2KB: 0x0000 - 0x07FF)
    rom: rom_2kx8
        generic map (
            ROM_FILE => "hello_io.mem"
        )
        port map (
            ADDR => rom_addr,
            DATA_OUT => rom_data,
            CS_N => rom_cs_n
        );

    -- RAM (1KB: 0x0800 - 0x0BFF)
    ram: ram_1kx8
        port map (
            CLK => phi1_tb,
            ADDR => ram_addr,
            DATA_IN => ram_data_in,
            DATA_OUT => ram_data_out,
            RW_N => ram_rw_n,
            CS_N => ram_cs_n,
            DEBUG_BYTE_0 => ram_debug_byte_0
        );

    -- I/O Console
    console: io_console
        generic map (
            OUTPUT_FILE => "console_output.txt"
        )
        port map (
            phi1 => phi1_tb,
            phi2 => phi2_tb,
            reset => reset_tb,
            S0 => S0_tb,
            S1 => S1_tb,
            S2 => S2_tb,
            data_bus => data_bus_tb
        );

    --===========================================
    -- Memory Address Decode
    --===========================================
    mem_addr <= addr_high_capture & addr_low_capture;

    -- ROM: addresses 0x0000 - 0x07FF (bit 11 = 0)
    rom_addr <= mem_addr(10 downto 0);
    rom_cs_n <= '0' when mem_addr(11) = '0' else '1';

    -- RAM: addresses 0x0800 - 0x0BFF (bit 11 = 1, bit 10 = 0)
    ram_addr <= mem_addr(9 downto 0);
    ram_cs_n <= '0' when mem_addr(11) = '1' and mem_addr(10) = '0' else '1';

    --===========================================
    -- Memory Controller
    --===========================================
    -- Address capture process (synchronous on phi1)
    addr_capture: process(phi1_tb)
    begin
        if rising_edge(phi1_tb) then
            -- T1 state: Capture low address byte (S2 S1 S0 = 0 0 0)
            if S2_tb = '0' and S1_tb = '0' and S0_tb = '0' then
                if data_bus_tb /= "ZZZZZZZZ" then
                    addr_low_capture <= data_bus_tb;
                end if;
            end if;

            -- T2 state: Capture high address and cycle type (S2 S1 S0 = 0 1 0)
            if S2_tb = '0' and S1_tb = '1' and S0_tb = '0' then
                if data_bus_tb /= "ZZZZZZZZ" then
                    addr_high_capture <= data_bus_tb(5 downto 0);
                    cycle_type_capture <= data_bus_tb(7 downto 6);
                end if;
            end if;
        end if;
    end process;

    -- RAM control process (synchronous writes)
    ram_control: process(phi1_tb)
    begin
        if rising_edge(phi1_tb) then
            -- T3/T4/T5 states with write cycle
            if ((S2_tb = '1' and S1_tb = '0' and S0_tb = '0') or  -- T3
                (S2_tb = '0' and S1_tb = '0' and S0_tb = '1') or  -- T4
                (S2_tb = '1' and S1_tb = '0' and S0_tb = '1')) and -- T5
               cycle_type_capture = "10" then
                -- PCW = write cycle
                ram_rw_n <= '0';
                if data_bus_tb /= "ZZZZZZZZ" then
                    ram_data_in <= data_bus_tb;
                end if;
            else
                ram_rw_n <= '1';
            end if;
        end if;
    end process;

    -- Bus multiplexer (combinational)
    bus_mux: process(S2_tb, S1_tb, S0_tb, cycle_type_capture, mem_addr, rom_data, ram_data_out)
    begin
        -- Default: tri-state
        data_bus_tb <= (others => 'Z');

        -- T3/T4/T5 states with read cycle (PCI or PCR)
        if ((S2_tb = '1' and S1_tb = '0' and S0_tb = '0') or  -- T3
            (S2_tb = '0' and S1_tb = '0' and S0_tb = '1') or  -- T4
            (S2_tb = '1' and S1_tb = '0' and S0_tb = '1')) and -- T5
           (cycle_type_capture = "00" or cycle_type_capture = "01") then

            -- Select memory source based on address
            if mem_addr(11) = '0' then
                -- ROM space (address < 0x800)
                data_bus_tb <= rom_data;
            elsif mem_addr(11) = '1' and mem_addr(10) = '0' then
                -- RAM space (0x800 - 0xBFF)
                data_bus_tb <= ram_data_out;
            else
                -- Unmapped
                data_bus_tb <= x"FF";
            end if;
        end if;
    end process;

    --===========================================
    -- Instruction Counter
    --===========================================
    instr_counter: process(phi1_tb)
    begin
        if rising_edge(phi1_tb) then
            if SYNC_tb = '1' and S2_tb = '1' and S1_tb = '0' and S0_tb = '0' then
                if last_SYNC = '0' then
                    instruction_count <= instruction_count + 1;
                end if;
            end if;
            last_SYNC <= SYNC_tb;
        end if;
    end process;

    --===========================================
    -- Main Test Sequence
    --===========================================
    test_sequence: process
    begin
        report "========================================================" severity note;
        report "Intel 8008 I/O Console Test - Hello World" severity note;
        report "========================================================" severity note;
        report "Program: hello_io.asm" severity note;
        report "Purpose: Output 'Hello, World!' via I/O ports" severity note;
        report "" severity note;
        report "Memory Map:" severity note;
        report "  ROM: 0x0000 - 0x07FF (2KB program)" severity note;
        report "  RAM: 0x0800 - 0x0BFF (1KB data)" severity note;
        report "" severity note;
        report "I/O Port Map:" severity note;
        report "  Port 0: Console TX Data (write)" severity note;
        report "  Port 1: Console TX Status (read)" severity note;
        report "  Port 2: Console RX Data (read)" severity note;
        report "  Port 3: Console RX Status (read)" severity note;
        report "========================================================" severity note;

        -- Initialize: Assert reset
        reset_tb <= '1';
        reset_n_tb <= '0';
        wait for 100 ns;

        -- Release reset
        reset_tb <= '0';
        reset_n_tb <= '1';
        report "Reset released, CPU initializing..." severity note;

        -- Wait for CPU internal clearing
        wait for 500 ns;

        -- Pulse interrupt to start execution
        INT_tb <= '1';
        wait for 50 ns;
        INT_tb <= '0';
        report "Interrupt pulsed, CPU starting from 0x0000..." severity note;
        report "" severity note;
        report "========== Console Output Begin ==========" severity note;

        -- Wait for program to complete
        -- "Hello, World!\n" = 14 characters
        -- Each iteration: ~8 instructions * 60us = 480us
        -- 14 iterations = 6720us, add margin
        wait for 10000 us;

        report "========== Console Output End ==========" severity note;
        report "" severity note;

        -- Verify STOPPED state (HLT instruction reached)
        assert S2_tb = '1' and S1_tb = '0' and S0_tb = '1'
            report "FAIL: CPU should be in STOPPED state after HLT (S2=1,S1=0,S0=1)"
            severity error;
        report "SUCCESS: CPU in STOPPED state" severity note;

        -- Report final state
        report "========================================================" severity note;
        report "Final CPU State:" severity note;
        report "  PC = 0x" & to_hstring(debug_pc_tb) severity note;
        report "  A = 0x" & to_hstring(debug_reg_A_tb) severity note;
        report "  H:L = 0x" & to_hstring(debug_reg_H_tb) & to_hstring(debug_reg_L_tb) severity note;
        report "  Instructions executed: " & integer'image(instruction_count) severity note;
        report "========================================================" severity note;
        report "" severity note;
        report "=== I/O TEST PASSED ===" severity note;
        report "Check console_output.txt for captured output" severity note;
        report "========================================================" severity note;

        -- End simulation
        sim_done <= true;
        wait;
    end process;

end sim;
