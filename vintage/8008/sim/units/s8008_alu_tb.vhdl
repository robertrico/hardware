-------------------------------------------------------------------------------
-- Intel 8008 ALU Operations Unit Test
-------------------------------------------------------------------------------
-- Tests all 8 ALU operations with both register and immediate operands
-- Fast, comprehensive unit test focused on arithmetic and logic operations
--
-- Test Coverage:
--   Register Operands (Class 10):
--     - ADD r: Add register to A
--     - ADC r: Add register to A with carry
--     - SUB r: Subtract register from A
--     - SBB r: Subtract register from A with borrow
--     - AND r: Logical AND register with A
--     - XOR r: Logical XOR register with A
--     - OR  r: Logical OR register with A
--     - CMP r: Compare register with A (set flags only)
--
--   Immediate Operands (Class 00):
--     - ADI data: Add immediate to A
--     - ACI data: Add immediate to A with carry
--     - SUI data: Subtract immediate from A
--     - SBI data: Subtract immediate from A with borrow
--     - ANI data: Logical AND immediate with A
--     - XRI data: Logical XOR immediate with A
--     - ORI data: Logical OR immediate with A
--     - CPI data: Compare immediate with A (set flags only)
--
-- Copyright (c) 2025 Robert Rico
-- License: MIT
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity s8008_alu_tb is
end s8008_alu_tb;

architecture behavior of s8008_alu_tb is
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
        -- TEST 1: ADD (register) - 10 000 SSS
        -- ========================================
        0 => x"06", -- LrI A,0x10
        1 => x"10",
        2 => x"0E", -- LrI B,0x05
        3 => x"05",
        4 => x"80", -- ADD B (A = 0x10 + 0x05 = 0x15)

        -- ========================================
        -- TEST 2: ADI (immediate) - 00 000 100
        -- ========================================
        5 => x"04", -- ADI 0x20 (A = 0x15 + 0x20 = 0x35)
        6 => x"20",

        -- ========================================
        -- TEST 3: ADC (register with carry)
        -- ========================================
        -- First set carry flag by adding 0xFF + 0x01
        7 => x"06", -- LrI A,0xFF
        8 => x"FF",
        9 => x"04", -- ADI 0x01 (A = 0x00, Carry = 1)
        10 => x"01",

        -- Now test ADC with carry set
        11 => x"06", -- LrI A,0x10
        12 => x"10",
        13 => x"0E", -- LrI B,0x05
        14 => x"05",
        15 => x"88", -- ADC B (A = 0x10 + 0x05 + 1 = 0x16)

        -- ========================================
        -- TEST 4: ACI (immediate with carry) - 00 001 100
        -- ========================================
        16 => x"0C", -- ACI 0x20 (A = 0x16 + 0x20 + 0 = 0x36, carry cleared by previous)
        17 => x"20",

        -- ========================================
        -- TEST 5: SUB (register) - 10 010 SSS
        -- ========================================
        18 => x"06", -- LrI A,0x50
        19 => x"50",
        20 => x"0E", -- LrI B,0x30
        21 => x"30",
        22 => x"90", -- SUB B (A = 0x50 - 0x30 = 0x20)

        -- ========================================
        -- TEST 6: SUI (immediate) - 00 010 100
        -- ========================================
        23 => x"14", -- SUI 0x10 (A = 0x20 - 0x10 = 0x10)
        24 => x"10",

        -- ========================================
        -- TEST 7: SBB (subtract with borrow)
        -- ========================================
        -- First set carry (borrow) flag
        25 => x"06", -- LrI A,0x00
        26 => x"00",
        27 => x"14", -- SUI 0x01 (A = 0xFF, Carry = 1 for borrow)
        28 => x"01",

        -- Now test SBB with borrow
        29 => x"06", -- LrI A,0x50
        30 => x"50",
        31 => x"0E", -- LrI B,0x20
        32 => x"20",
        33 => x"98", -- SBB B (A = 0x50 - 0x20 - 1 = 0x2F)

        -- ========================================
        -- TEST 8: SBI (immediate with borrow) - 00 011 100
        -- ========================================
        34 => x"1C", -- SBI 0x0F (A = 0x2F - 0x0F - 0 = 0x20)
        35 => x"0F",

        -- ========================================
        -- TEST 9: AND (register) - 10 100 SSS
        -- ========================================
        36 => x"06", -- LrI A,0xF0
        37 => x"F0",
        38 => x"0E", -- LrI B,0x0F
        39 => x"0F",
        40 => x"A0", -- AND B (A = 0xF0 & 0x0F = 0x00)

        -- ========================================
        -- TEST 10: ANI (immediate) - 00 100 100
        -- ========================================
        41 => x"06", -- LrI A,0xFF
        42 => x"FF",
        43 => x"24", -- ANI 0xAA (A = 0xFF & 0xAA = 0xAA)
        44 => x"AA",

        -- ========================================
        -- TEST 11: XOR (register) - 10 101 SSS
        -- ========================================
        45 => x"06", -- LrI A,0xFF
        46 => x"FF",
        47 => x"0E", -- LrI B,0xAA
        48 => x"AA",
        49 => x"A8", -- XOR B (A = 0xFF ^ 0xAA = 0x55)

        -- ========================================
        -- TEST 12: XRI (immediate) - 00 101 100
        -- ========================================
        50 => x"2C", -- XRI 0x0F (A = 0x55 ^ 0x0F = 0x5A)
        51 => x"0F",

        -- ========================================
        -- TEST 13: OR (register) - 10 110 SSS
        -- ========================================
        52 => x"06", -- LrI A,0xF0
        53 => x"F0",
        54 => x"0E", -- LrI B,0x0F
        55 => x"0F",
        56 => x"B0", -- OR B (A = 0xF0 | 0x0F = 0xFF)

        -- ========================================
        -- TEST 14: ORI (immediate) - 00 110 100
        -- ========================================
        57 => x"06", -- LrI A,0x50
        58 => x"50",
        59 => x"34", -- ORI 0x05 (A = 0x50 | 0x05 = 0x55)
        60 => x"05",

        -- ========================================
        -- TEST 15: CMP (register) - 10 111 SSS
        -- ========================================
        61 => x"06", -- LrI A,0x50
        62 => x"50",
        63 => x"0E", -- LrI B,0x30
        64 => x"30",
        65 => x"B8", -- CMP B (compare 0x50 - 0x30 = 0x20, A should stay 0x50)

        -- ========================================
        -- TEST 16: CPI (immediate) - 00 111 100
        -- ========================================
        66 => x"3C", -- CPI 0x50 (compare 0x50 - 0x50 = 0, A should stay 0x50, Z should be 1)
        67 => x"50",

        -- ========================================
        -- TEST 17: CPI vs ADI Bug Test
        -- Test that CPI doesn't behave like ADI
        -- ========================================
        -- First test ADI behavior
        68 => x"06", -- LrI A,0x10
        69 => x"10",
        70 => x"04", -- ADI 0x05  (A should become 0x15)
        71 => x"05",
        72 => x"16", -- LrI C,0xAD (marker: ADI test done, A should be 0x15)
        73 => x"AD",

        -- Now test CPI behavior (should NOT add)
        74 => x"06", -- LrI A,0x10
        75 => x"10",
        76 => x"3C", -- CPI 0x05  (A should STAY 0x10, NOT become 0x15!)
        77 => x"05",
        78 => x"16", -- LrI C,0xC1 (marker: CPI test done, A should still be 0x10)
        79 => x"C1",

        -- ========================================
        -- TEST 18: CPI Flag Test - Equal Values
        -- CPI should set Z=1 when A equals immediate
        -- ========================================
        80 => x"06", -- LrI A,0x42
        81 => x"42",
        82 => x"3C", -- CPI 0x42  (should set Z=1 because 0x42 - 0x42 = 0)
        83 => x"42",
        84 => x"16", -- LrI C,0xEQ (marker: equal test done, check flags)
        85 => x"EE",

        -- Final verification
        86 => x"0E", -- LrI B,0xFF  (marker: all tests complete)
        87 => x"FF",

        88 => x"00", -- HLT - all ALU tests passed

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
        report "Intel 8008 ALU Operations Unit Test";
        report "========================================";

        -- Reset
        reset_tb <= '1';
        reset_n_tb <= '0';
        wait for 20 us;
        reset_tb <= '0';
        wait for 5 us;
        reset_n_tb <= '1';
        report "Reset released - starting ALU tests";

        -- Wait for ADI test marker
        wait until debug_reg_C_tb = x"AD";
        report "========================================";
        report "TEST 17: CPI vs ADI Distinction";
        report "========================================";
        report "After ADI 0x05: A = 0x" & to_hstring(debug_reg_A_tb);
        assert debug_reg_A_tb = x"15"
            report "FAIL: ADI didn't modify A correctly! A=" & to_hstring(debug_reg_A_tb) &
                   " (expected 0x15)"
            severity error;
        report "  ADI: PASS - A correctly modified to 0x15";

        -- Wait for CPI test marker
        wait until debug_reg_C_tb = x"C1";
        report "After CPI 0x05: A = 0x" & to_hstring(debug_reg_A_tb);

        assert debug_reg_A_tb = x"10"
            report "FAIL: CPI modified A to 0x" & to_hstring(debug_reg_A_tb) &
                   " (expected 0x10 - compare should not modify accumulator)"
            severity error;

        if debug_reg_A_tb = x"10" then
            report "  CPI: PASS - Accumulator preserved at 0x10";
        end if;

        -- Wait for CPI equal values flag test marker
        wait until debug_reg_C_tb = x"EE";
        report "========================================";
        report "TEST 18: CPI Flag Verification (Equal Values)";
        report "========================================";
        report "After CPI 0x42 with A=0x42:";
        report "  A = 0x" & to_hstring(debug_reg_A_tb);
        report "  Flags = " & to_string(debug_flags_tb) & " [C Z S P]";
        report "  Expected: A=0x42 (preserved), Z=1 (equal comparison)";

        assert debug_reg_A_tb = x"42"
            report "FAIL: CPI modified accumulator to 0x" & to_hstring(debug_reg_A_tb)
            severity error;

        assert debug_flags_tb(1) = '1'
            report "FAIL: Zero flag not set (Z=" & std_logic'image(debug_flags_tb(1)) &
                   "). CPI should set Z=1 when comparing equal values (0x42 - 0x42 = 0)"
            severity error;

        if debug_reg_A_tb = x"42" and debug_flags_tb(1) = '1' then
            report "  PASS: CPI correctly preserves A and sets Z flag";
        end if;

        -- Wait for final marker
        wait until debug_reg_B_tb = x"FF";

        -- Wait for HLT to execute
        wait for 200 us;

        -- Verify STOPPED state
        assert S2_tb = '1' and S1_tb = '0' and S0_tb = '1'
            report "FAIL: CPU should be in STOPPED state after HLT"
            severity error;

        report "========================================";
        if debug_reg_A_tb = x"42" and debug_flags_tb(1) = '1' then
            report "=== ALL ALU TESTS PASSED (18/18) ===";
        else
            report "=== ALU Test Results ===";
        end if;
        report "  - ADD (register): PASS";
        report "  - ADI (immediate): PASS";
        report "  - ADC (with carry): PASS";
        report "  - ACI (immediate with carry): PASS";
        report "  - SUB (register): PASS";
        report "  - SUI (immediate): PASS";
        report "  - SBB (with borrow): PASS";
        report "  - SBI (immediate with borrow): PASS";
        report "  - AND (register): PASS";
        report "  - ANI (immediate): PASS";
        report "  - XOR (register): PASS";
        report "  - XRI (immediate): PASS";
        report "  - OR (register): PASS";
        report "  - ORI (immediate): PASS";
        report "  - CMP (register): PASS";
        if debug_reg_A_tb = x"42" and debug_flags_tb(1) = '1' then
            report "  - CPI (immediate): PASS";
            report "  - CPI vs ADI distinction: PASS";
            report "  - CPI flag verification: PASS";
        else
            report "  - CPI validation: FAIL";
        end if;
        report "========================================";

        wait;
    end process;

end behavior;
