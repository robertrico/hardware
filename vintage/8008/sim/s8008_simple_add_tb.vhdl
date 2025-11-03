-------------------------------------------------------------------------------
-- Testbench for Intel 8008 - Simple ADD Test Program
-------------------------------------------------------------------------------
-- Hardware-accurate testbench using real ROM and RAM components
-- Designed to be scalable toward full SIM8-01 computer system
--
-- Memory Map:
--   0x0000 - 0x07FF (2KB):  ROM (program memory)
--   0x0800 - 0x0BFF (1KB):  RAM (data memory)
--
-- Program Flow (simple_add.asm):
--   1. MVI A, 5
--   2. MVI B, 3
--   3. ADD B (A = A + B = 8)
--   4. MVI H, 0x08
--   5. MVI L, 0x00
--   6. MOV M, A (write result to RAM[0x0800])
--   7. HLT
--
-- Expected Results (at HLT):
--   A: Result of 5 + 3 (0x08)
--   B: Second operand (0x03)
--   H: RAM base high (0x08)
--   L: RAM base low (0x00)
--   RAM[0x0800]: 0x08
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity s8008_simple_add_tb is
end s8008_simple_add_tb;

architecture sim of s8008_simple_add_tb is

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

    component rom_2kx8 is
        generic(
            ROM_FILE : string := "test_programs/simple_add.mem"
        );
        port (
            ADDR : in std_logic_vector(10 downto 0);
            DATA_OUT : out std_logic_vector(7 downto 0);
            CS_N : in std_logic
        );
    end component;

    component ram_1kx8 is
        port (
            CLK : in std_logic;
            ADDR : in std_logic_vector(9 downto 0);
            DATA_IN : in std_logic_vector(7 downto 0);
            DATA_OUT : out std_logic_vector(7 downto 0);
            RW_N : in std_logic;
            CS_N : in std_logic;
            DEBUG_BYTE_0 : out std_logic_vector(7 downto 0)
        );
    end component;

    component phase_clocks is
        port (
            clk_in : in std_logic;
            reset : in std_logic;
            phi1 : out std_logic;
            phi2 : out std_logic
        );
    end component;

    -- CPU signals
    signal phi1_tb : std_logic := '0';
    signal phi2_tb : std_logic := '0';
    signal reset_tb : std_logic := '1';  -- Active high for testbench convenience
    signal reset_n_tb : std_logic := '0';  -- Active low for CPU
    signal data_bus_tb : std_logic_vector(7 downto 0);
    signal S0_tb, S1_tb, S2_tb : std_logic;
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

    -- Clock signal
    signal master_clk_tb : std_logic := '0';

    -- Memory signals
    signal mem_addr : std_logic_vector(13 downto 0);
    signal addr_low_capture : std_logic_vector(7 downto 0) := x"00";
    signal addr_high_capture : std_logic_vector(5 downto 0) := "000000";
    signal cycle_type_capture : std_logic_vector(1 downto 0) := "00";

    -- ROM signals
    signal rom_addr : std_logic_vector(10 downto 0);
    signal rom_data : std_logic_vector(7 downto 0);
    signal rom_cs_n : std_logic := '1';

    -- RAM signals
    signal ram_addr : std_logic_vector(9 downto 0);
    signal ram_data_in : std_logic_vector(7 downto 0) := x"00";
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
    -- Phase Clock Generator
    --===========================================
    clk_gen: phase_clocks
        port map (
            clk_in => master_clk_tb,
            reset => reset_tb,
            phi1 => phi1_tb,
            phi2 => phi2_tb
        );

    --===========================================
    -- Device Under Test
    --===========================================
    dut: s8008
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

    --===========================================
    -- ROM Component (2KB)
    --===========================================
    rom: rom_2kx8
        generic map (
            ROM_FILE => "test_programs/simple_add.mem"
        )
        port map (
            ADDR => rom_addr,
            DATA_OUT => rom_data,
            CS_N => rom_cs_n
        );

    --===========================================
    -- RAM Component (1KB)
    --===========================================
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
    -- This process handles the 8008 bus protocol:
    -- T1: CPU outputs low address byte
    -- T2: CPU outputs high address bits [5:0] and cycle type [7:6]
    -- T3/T4/T5: Data transfer (CPU reads or writes)
    --
    -- Key: This must be a clocked process to avoid race conditions
    --===========================================

    -- Address capture process (synchronous on phi1)
    -- This mimics hardware address latches that capture on clock edges
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

    -- Bus multiplexer (combinational - mimics asynchronous memory response)
    -- ROM chips have no CLK input - they respond purely to address/CS changes
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
    -- Halt Detection and Verification
    --===========================================

    -- Instruction counter (for debugging)
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
        -- Wait for clock stabilization
        wait for 20 ns;

        report "========================================================";
        report "Intel 8008 Simple ADD Test";
        report "========================================================";
        report "Testing basic arithmetic and RAM write:";
        report "  - Load A=5, B=3";
        report "  - ADD B (A = 5 + 3 = 8)";
        report "  - Write result to RAM[0x0800]";
        report "========================================================";

        -- Initialize: Assert reset
        reset_tb <= '1';
        reset_n_tb <= '0';
        wait for 100 ns;

        -- Release reset
        reset_tb <= '0';
        reset_n_tb <= '1';
        report "Reset released, waiting for CPU to clear internal state..." severity note;

        -- Per Intel 8008 User's Manual: CPU enters STOPPED state on power-up
        -- Requires 16 clock periods to clear memories, then INT pulse to start
        wait for 500 ns;  -- Wait for internal clearing (16 clocks @ ~2.2us/clock)

        -- Pulse interrupt to escape STOPPED state and begin execution
        INT_tb <= '1';
        wait for 50 ns;
        INT_tb <= '0';
        report "Interrupt pulsed, CPU starting execution from 0x0000..." severity note;

        -- Wait for program to complete
        -- Program performs:
        --   - 7 simple instructions (MVI, ADD, MOV, HLT)
        -- Total ~7 instructions, each ~25us = ~175us, add margin
        wait for 500 us;

        -- Verify STOPPED state (HLT instruction reached)
        assert S2_tb = '1' and S1_tb = '0' and S0_tb = '1'
            report "FAIL: CPU should be in STOPPED state after HLT (S2=1,S1=0,S0=1)"
            severity error;
        report "SUCCESS: CPU in STOPPED state" severity note;

        -- Report final register state
        report "========================================================" severity note;
        report "Final register state:" severity note;
        report "  A = 0x" & to_hstring(debug_reg_A_tb) & " (result: expect 0x08)" severity note;
        report "  B = 0x" & to_hstring(debug_reg_B_tb) & " (second operand: expect 0x03)" severity note;
        report "  H = 0x" & to_hstring(debug_reg_H_tb) & " (RAM base high: expect 0x08)" severity note;
        report "  L = 0x" & to_hstring(debug_reg_L_tb) & " (RAM base low: expect 0x00)" severity note;
        report "  PC = 0x" & to_hstring(debug_pc_tb) severity note;
        report "  Flags = " & to_string(debug_flags_tb) severity note;
        report "  Instructions executed: " & integer'image(instruction_count) severity note;
        report "  RAM[0x0800] = 0x" & to_hstring(ram_debug_byte_0) & " (result: expect 0x08)" severity note;

        -- Verification checks
        report "========================================================" severity note;
        report "Verification:" severity note;

        -- Check result (A = 5 + 3 = 0x08)
        assert debug_reg_A_tb = x"08"
            report "FAIL: Result incorrect! A=" & to_hstring(debug_reg_A_tb) &
                   " (expected 0x08)"
            severity error;

        if debug_reg_A_tb = x"08" then
            report "  PASS: Result correct (A=0x08)" severity note;
        end if;

        -- Check second operand (B = 0x03)
        assert debug_reg_B_tb = x"03"
            report "FAIL: Second operand incorrect! B=" & to_hstring(debug_reg_B_tb) &
                   " (expected 0x03)"
            severity error;

        if debug_reg_B_tb = x"03" then
            report "  PASS: Second operand correct (B=0x03)" severity note;
        end if;

        -- Check RAM base address high (H = 0x08)
        assert debug_reg_H_tb = x"08"
            report "FAIL: RAM base high incorrect! H=" & to_hstring(debug_reg_H_tb) &
                   " (expected 0x08)"
            severity error;

        if debug_reg_H_tb = x"08" then
            report "  PASS: RAM base high correct (H=0x08)" severity note;
        end if;

        -- Check RAM base address low (L = 0x00)
        assert debug_reg_L_tb = x"00"
            report "FAIL: RAM base low incorrect! L=" & to_hstring(debug_reg_L_tb) &
                   " (expected 0x00)"
            severity error;

        if debug_reg_L_tb = x"00" then
            report "  PASS: RAM base low correct (L=0x00)" severity note;
        end if;

        -- Check RAM[0x0800] via debug port (should be 0x08)
        assert ram_debug_byte_0 = x"08"
            report "FAIL: RAM[0x0800] incorrect! Value=" & to_hstring(ram_debug_byte_0) &
                   " (expected 0x08)"
            severity error;

        if ram_debug_byte_0 = x"08" then
            report "  PASS: RAM[0x0800] correct (0x08)" severity note;
        end if;

        -- Final verdict
        if debug_reg_A_tb = x"08" and
           debug_reg_B_tb = x"03" and
           debug_reg_H_tb = x"08" and
           debug_reg_L_tb = x"00" and
           ram_debug_byte_0 = x"08" then
            report "========================================================" severity note;
            report "=== SIMPLE ADD TEST PASSED ===" severity note;
            report "========================================================" severity note;
        else
            report "========================================================" severity error;
            report "=== SIMPLE ADD TEST FAILED ===" severity error;
            report "========================================================" severity error;
        end if;

        sim_done <= true;
        wait;
    end process;

end sim;
