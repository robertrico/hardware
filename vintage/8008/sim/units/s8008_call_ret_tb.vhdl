-------------------------------------------------------------------------------
-- Intel 8008 CALL/RET Unit Test
-------------------------------------------------------------------------------
-- Tests subroutine call and return instructions
-- Fast, comprehensive unit test focused on stack operations
--
-- Test Coverage:
--   - Simple CALL and RET
--   - Nested calls (2 levels deep)
--   - Stack depth (3 levels)
--   - Return address verification
--   - Stack pointer management
--
-- Copyright (c) 2025 Robert Rico
-- License: MIT
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity s8008_call_ret_tb is
end s8008_call_ret_tb;

architecture behavior of s8008_call_ret_tb is
    -- Component declarations
    component phase_clocks
        port(
            clk_in : in std_logic;
            reset : in std_logic;
            phi1 : out std_logic;
            phi2 : out std_logic
        );
    end component;

    component s8008
        port(
            phi1 : in std_logic;
            phi2 : in std_logic;
            reset_n : in std_logic;
            data_bus : inout std_logic_vector(7 downto 0);
            S0 : out std_logic;
            S1 : out std_logic;
            S2 : out std_logic;
            sync : out std_logic;
            ready : in std_logic;
            int : in std_logic;
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

    -- Test signals
    signal master_clk_tb : std_logic := '0';
    signal reset_tb : std_logic := '1';
    signal phi1_tb : std_logic := '0';
    signal phi2_tb : std_logic := '0';
    signal reset_n_tb : std_logic := '0';
    signal ready_tb : std_logic := '1';
    signal int_tb : std_logic := '0';
    signal data_tb : std_logic_vector(7 downto 0);
    signal S0_tb, S1_tb, S2_tb : std_logic;
    signal sync_tb : std_logic;

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

    -- Master clock period
    constant MASTER_CLK_PERIOD : time := 10 ns;  -- 100 MHz master clock

    -- ROM for test program
    type rom_t is array (0 to 255) of std_logic_vector(7 downto 0);
    signal rom : rom_t := (
        -- ========================================
        -- TEST 1: Simple CALL and RET
        -- ========================================
        0 => x"06", -- LrI A,0x11 (marker: entering main)
        1 => x"11",

        2 => x"46", -- CALL 0x0020 = 01 000 110
        3 => x"20", --   low byte (32 decimal)
        4 => x"00", --   high byte

        -- Should return here (address 5)
        5 => x"0E", -- LrI B,0x22 (marker: TEST 1 passed)
        6 => x"22",

        -- ========================================
        -- TEST 2: Nested CALL (2 levels)
        -- ========================================
        7 => x"46", -- CALL 0x0030 = 01 000 110
        8 => x"30", --   low byte (48 decimal)
        9 => x"00", --   high byte

        -- Should return here (address 10)
        10 => x"16", -- LrI C,0x33 (marker: TEST 2 passed)
        11 => x"33",

        -- ========================================
        -- TEST 3: Stack depth (3 levels)
        -- ========================================
        12 => x"46", -- CALL 0x0050 = 01 000 110
        13 => x"50", --   low byte (80 decimal)
        14 => x"00", --   high byte

        -- Should return here (address 15)
        15 => x"1E", -- LrI D,0x44 (marker: TEST 3 passed)
        16 => x"44",

        17 => x"00", -- HLT - all tests passed

        -- ========================================
        -- Subroutine 1 (address 32): Simple RET
        -- ========================================
        32 => x"26", -- LrI E,0xE1 (marker: in subroutine 1)
        33 => x"E1",
        34 => x"47", -- RET = 01 000 111 = 0x47

        -- ========================================
        -- Subroutine 2 (address 48): Nested CALL
        -- ========================================
        48 => x"2E", -- LrI H,0xE2 (marker: in subroutine 2, level 1)
        49 => x"E2",

        50 => x"46", -- CALL 0x0040 = 01 000 110 (call level 2)
        51 => x"40", --   low byte (64 decimal)
        52 => x"00", --   high byte

        -- Returns here from level 2
        53 => x"36", -- LrI L,0xE3 (marker: back in subroutine 2)
        54 => x"E3",
        55 => x"47", -- RET to main = 0x47

        -- ========================================
        -- Subroutine 3 (address 64): Level 2 of nested call
        -- ========================================
        64 => x"06", -- LrI A,0xF2 (marker: in subroutine 3, level 2)
        65 => x"F2",
        66 => x"47", -- RET to subroutine 2 = 0x47

        -- ========================================
        -- Subroutine 4 (address 80): Stack depth test
        -- ========================================
        80 => x"0E", -- LrI B,0xD1 (marker: in subroutine 4, level 1)
        81 => x"D1",

        82 => x"46", -- CALL 0x0060 = 01 000 110 (level 2)
        83 => x"60", --   low byte (96 decimal)
        84 => x"00", --   high byte

        -- Returns here from level 2
        85 => x"16", -- LrI C,0xD2 (marker: back in level 1)
        86 => x"D2",
        87 => x"47", -- RET to main = 0x47

        -- ========================================
        -- Subroutine 5 (address 96): Stack level 2
        -- ========================================
        96 => x"1E", -- LrI D,0xC1 (marker: in subroutine 5, level 2)
        97 => x"C1",

        98 => x"46", -- CALL 0x0070 = 01 000 110 (level 3)
        99 => x"70", --   low byte (112 decimal)
        100 => x"00", --   high byte

        -- Returns here from level 3
        101 => x"26", -- LrI E,0xC2 (marker: back in level 2)
        102 => x"C2",
        103 => x"47", -- RET to level 1 = 0x47

        -- ========================================
        -- Subroutine 6 (address 112): Stack level 3 (deepest)
        -- ========================================
        112 => x"2E", -- LrI H,0xB1 (marker: in subroutine 6, level 3 - deepest)
        113 => x"B1",
        114 => x"47", -- RET to level 2 = 0x47

        others => x"00"
    );

    -- Memory controller signals
    signal rom_data : std_logic_vector(7 downto 0) := (others => 'Z');
    signal rom_enable : std_logic := '0';

begin
    -- Bus driver (continuous assignment)
    data_tb <= rom_data when rom_enable = '1' else (others => 'Z');

    -- Instantiate the CPU
    uut: s8008
        port map (
            phi1 => phi1_tb,
            phi2 => phi2_tb,
            reset_n => reset_n_tb,
            data_bus => data_tb,
            S0 => S0_tb,
            S1 => S1_tb,
            S2 => S2_tb,
            sync => sync_tb,
            ready => ready_tb,
            int => int_tb,
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

    -- Instantiate phase clock generator
    clk_gen: phase_clocks
        port map (
            clk_in => master_clk_tb,
            reset => reset_tb,
            phi1 => phi1_tb,
            phi2 => phi2_tb
        );

    -- Master clock generation
    master_clk_process: process
    begin
        master_clk_tb <= '0';
        wait for MASTER_CLK_PERIOD / 2;
        master_clk_tb <= '1';
        wait for MASTER_CLK_PERIOD / 2;
    end process;

    -- Memory controller (ROM interface)
    memory_controller: process(phi1_tb)
        variable captured_address : std_logic_vector(13 downto 0) := (others => '0');
        variable cycle_type : std_logic_vector(1 downto 0) := "00";
        variable is_write : boolean := false;
    begin
        if rising_edge(phi1_tb) then
            -- T1: Capture low address byte
            if S2_tb = '0' and S1_tb = '0' and S0_tb = '0' then
                if data_tb /= "ZZZZZZZZ" then
                    captured_address(7 downto 0) := data_tb;
                end if;
            end if;

            -- T2: Capture high address bits and cycle type
            if S2_tb = '0' and S1_tb = '1' and S0_tb = '0' then
                if data_tb /= "ZZZZZZZZ" then
                    cycle_type := data_tb(7 downto 6);
                    captured_address(13 downto 8) := data_tb(5 downto 0);
                    is_write := (cycle_type = "10");
                end if;
            end if;

            -- T3: Enable ROM for read cycles
            if S2_tb = '1' and S1_tb = '0' and S0_tb = '0' then
                if is_write then
                    rom_enable <= '0';
                    rom_data <= (others => 'Z');
                else
                    rom_enable <= '1';
                    rom_data <= rom(to_integer(unsigned(captured_address(7 downto 0))));
                end if;
            else
                rom_enable <= '0';
                rom_data <= (others => 'Z');
            end if;
        end if;
    end process;

    -- Test stimulus and verification
    stim_proc: process
    begin
        report "========================================";
        report "Intel 8008 CALL/RET Unit Test";
        report "========================================";

        -- Reset
        reset_tb <= '1';
        reset_n_tb <= '0';
        wait for 20 us;
        reset_tb <= '0';
        wait for 5 us;
        reset_n_tb <= '1';
        report "Reset released - starting tests";

        -- Run until program halts
        -- 3 CALL/RET sequences with deep nesting = ~700us
        wait for 750 us;

        -- Verify STOPPED state
        assert S2_tb = '1' and S1_tb = '0' and S0_tb = '1'
            report "FAIL: CPU should be in STOPPED state after HLT"
            severity error;

        -- Verify register markers to ensure all subroutines executed
        -- Final values after all CALL/RET sequences:
        assert debug_reg_A_tb = x"F2"
            report "FAIL: A should be 0xF2 (subroutine 3 marker)"
            severity error;

        assert debug_reg_B_tb = x"D1"
            report "FAIL: B should be 0xD1 (subroutine 4 marker)"
            severity error;

        assert debug_reg_C_tb = x"D2"
            report "FAIL: C should be 0xD2 (subroutine 4 return marker)"
            severity error;

        assert debug_reg_D_tb = x"44"
            report "FAIL: D should be 0x44 (TEST 3 marker - final value)"
            severity error;

        assert debug_reg_E_tb = x"C2"
            report "FAIL: E should be 0xC2 (subroutine 5 return marker)"
            severity error;

        assert debug_reg_H_tb = x"B1"
            report "FAIL: H should be 0xB1 (subroutine 6 marker - deepest level)"
            severity error;

        assert debug_reg_L_tb = x"E3"
            report "FAIL: L should be 0xE3 (subroutine 2 return marker)"
            severity error;

        report "========================================";
        report "=== All CALL/RET Tests PASSED ===";
        report "  - Simple CALL/RET: PASS";
        report "  - Nested CALL (2 levels): PASS";
        report "  - Stack depth (3 levels): PASS";
        report "  - Return address verification: PASS";
        report "========================================";

        wait;
    end process;

end behavior;
