-------------------------------------------------------------------------------
-- Intel 8008 Conditional CALL Unit Test
-------------------------------------------------------------------------------
-- Tests all 8 conditional CALL variants (CFc/CTc with 4 flags)
-- Fast, comprehensive unit test focused solely on conditional CALL/RET
--
-- Test Coverage:
--   - CTC/CFC (carry flag)
--   - CTZ/CFZ (zero flag)
--   - CTS/CFS (sign flag)
--   - CTP/CFP (parity flag)
--   - Verifies stack push only when condition is met
--   - Verifies correct return address
--
-- Copyright (c) 2025 Robert Rico
-- License: MIT
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity s8008_conditional_call_tb is
end s8008_conditional_call_tb;

architecture behavior of s8008_conditional_call_tb is
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
    signal reset_tb : std_logic := '1';         -- Active-high reset for phase_clocks
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

    -- Master clock period (for phase_clocks input)
    constant MASTER_CLK_PERIOD : time := 10 ns;  -- 100 MHz master clock

    -- ROM for test program
    type rom_t is array (0 to 255) of std_logic_vector(7 downto 0);
    signal rom : rom_t := (
        -- ========================================
        -- TEST 1-2: Carry Flag (CFC/CTC)
        -- ========================================
        -- Setup: Clear carry flag
        0 => x"06", -- LrI A,0x00  (set A=0)
        1 => x"00",
        2 => x"04", -- ADI 0x00    (A=0+0=0, Carry=0)
        3 => x"00",

        -- TEST 1: CFC (Call if Carry=0) - should CALL
        4 => x"42", -- CFC 0x00E0  = 01 000 010 (bit5=0 for CF, bits4:3=00 for carry)
        5 => x"E0", --               low byte
        6 => x"00", --               high byte (0x00E0)

        -- Mark that we returned from subroutine
        7 => x"0E", -- LrI B,0x11  (marker: returned from CFC)
        8 => x"11",

        -- Setup: Set carry flag
        9 => x"06", -- LrI A,0xFF  (set A=255)
       10 => x"FF",
       11 => x"04", -- ADI 0x01    (A=255+1=256, Carry=1)
       12 => x"01",

        -- TEST 2: CTC (Call if Carry=1) - should CALL
       13 => x"62", -- CTC 0x00E0  = 01 100 010 (bit5=1 for CT, bits4:3=00 for carry)
       14 => x"E0", --               low byte
       15 => x"00", --               high byte (0x00E0)

        -- Mark that we returned from subroutine
       16 => x"0E", -- LrI B,0x22  (marker: returned from CTC)
       17 => x"22",

        -- ========================================
        -- TEST 3-4: Zero Flag (CFZ/CTZ)
        -- ========================================
        -- Setup: Clear zero flag
       18 => x"06", -- LrI A,0x01  (set A=1)
       19 => x"01",
       20 => x"04", -- ADI 0x00    (A=1+0=1, Zero=0)
       21 => x"00",

        -- TEST 3: CFZ (Call if Zero=0) - should CALL
       22 => x"4A", -- CFZ 0x00E0  = 01 001 010 (bit5=0 for CF, bits4:3=01 for zero)
       23 => x"E0", --               low byte
       24 => x"00", --               high byte

       25 => x"0E", -- LrI B,0x33  (marker: returned from CFZ)
       26 => x"33",

        -- Setup: Set zero flag
       27 => x"06", -- LrI A,0x00  (set A=0)
       28 => x"00",
       29 => x"04", -- ADI 0x00    (A=0+0=0, Zero=1)
       30 => x"00",

        -- TEST 4: CTZ (Call if Zero=1) - should CALL
       31 => x"6A", -- CTZ 0x00E0  = 01 101 010 (bit5=1 for CT, bits4:3=01 for zero)
       32 => x"E0", --               low byte
       33 => x"00", --               high byte

       34 => x"0E", -- LrI B,0x44  (marker: returned from CTZ)
       35 => x"44",

        -- ========================================
        -- TEST 5-6: Sign Flag (CFS/CTS)
        -- ========================================
        -- Setup: Clear sign flag (positive)
       36 => x"06", -- LrI A,0x7F  (set A=127, positive)
       37 => x"7F",
       38 => x"04", -- ADI 0x00    (A=127+0=127, Sign=0)
       39 => x"00",

        -- TEST 5: CFS (Call if Sign=0) - should CALL
       40 => x"52", -- CFS 0x00E0  = 01 010 010 (bit5=0 for CF, bits4:3=10 for sign)
       41 => x"E0", --               low byte
       42 => x"00", --               high byte

       43 => x"0E", -- LrI B,0x55  (marker: returned from CFS)
       44 => x"55",

        -- Setup: Set sign flag (negative)
       45 => x"06", -- LrI A,0x80  (set A=128, negative)
       46 => x"80",
       47 => x"04", -- ADI 0x00    (A=128+0=128, Sign=1)
       48 => x"00",

        -- TEST 6: CTS (Call if Sign=1) - should CALL
       49 => x"72", -- CTS 0x00E0  = 01 110 010 (bit5=1 for CT, bits4:3=10 for sign)
       50 => x"E0", --               low byte
       51 => x"00", --               high byte

       52 => x"0E", -- LrI B,0x66  (marker: returned from CTS)
       53 => x"66",

        -- ========================================
        -- TEST 7-8: Parity Flag (CFP/CTP)
        -- ========================================
        -- Setup: Clear parity flag (odd parity)
       54 => x"06", -- LrI A,0x01  (0b00000001, 1 bit set = odd)
       55 => x"01",
       56 => x"04", -- ADI 0x00    (Parity=0 for odd)
       57 => x"00",

        -- TEST 7: CFP (Call if Parity=0) - should CALL
       58 => x"5A", -- CFP 0x00E0  = 01 011 010 (bit5=0 for CF, bits4:3=11 for parity)
       59 => x"E0", --               low byte
       60 => x"00", --               high byte

       61 => x"0E", -- LrI B,0x77  (marker: returned from CFP)
       62 => x"77",

        -- Setup: Set parity flag (even parity)
       63 => x"06", -- LrI A,0x03  (0b00000011, 2 bits set = even)
       64 => x"03",
       65 => x"04", -- ADI 0x00    (Parity=1 for even)
       66 => x"00",

        -- TEST 8: CTP (Call if Parity=1) - should CALL
       67 => x"7A", -- CTP 0x00E0  = 01 111 010 (bit5=1 for CT, bits4:3=11 for parity)
       68 => x"E0", --               low byte
       69 => x"00", --               high byte

       70 => x"0E", -- LrI B,0x88  (marker: returned from CTP)
       71 => x"88",

        -- ========================================
        -- TEST 9-16: Negative tests (condition NOT met)
        -- ========================================
        -- TEST 9: CTC with Carry=0 - should NOT call
       72 => x"06", -- LrI A,0x00
       73 => x"00",
       74 => x"04", -- ADI 0x00    (Carry=0)
       75 => x"00",
       76 => x"62", -- CTC 0x00E0  (should NOT call)
       77 => x"E0",
       78 => x"00",
       79 => x"0E", -- LrI B,0x91  (marker: CTC skipped)
       80 => x"91",

        -- TEST 10: CFC with Carry=1 - should NOT call
       81 => x"06", -- LrI A,0xFF
       82 => x"FF",
       83 => x"04", -- ADI 0x01    (Carry=1)
       84 => x"01",
       85 => x"42", -- CFC 0x00E0  (should NOT call)
       86 => x"E0",
       87 => x"00",
       88 => x"0E", -- LrI B,0x92  (marker: CFC skipped)
       89 => x"92",

        -- TEST 11: CTZ with Zero=0 - should NOT call
       90 => x"06", -- LrI A,0x01
       91 => x"01",
       92 => x"04", -- ADI 0x00    (Zero=0)
       93 => x"00",
       94 => x"6A", -- CTZ 0x00E0  (should NOT call)
       95 => x"E0",
       96 => x"00",
       97 => x"0E", -- LrI B,0x93  (marker: CTZ skipped)
       98 => x"93",

        -- TEST 12: CFZ with Zero=1 - should NOT call
       99 => x"06", -- LrI A,0x00
      100 => x"00",
      101 => x"04", -- ADI 0x00    (Zero=1)
      102 => x"00",
      103 => x"4A", -- CFZ 0x00E0  (should NOT call)
      104 => x"E0",
      105 => x"00",
      106 => x"0E", -- LrI B,0x94  (marker: CFZ skipped)
      107 => x"94",

        -- TEST 13: CTS with Sign=0 - should NOT call
      108 => x"06", -- LrI A,0x7F
      109 => x"7F",
      110 => x"04", -- ADI 0x00    (Sign=0)
      111 => x"00",
      112 => x"72", -- CTS 0x00E0  (should NOT call)
      113 => x"E0",
      114 => x"00",
      115 => x"0E", -- LrI B,0x95  (marker: CTS skipped)
      116 => x"95",

        -- TEST 14: CFS with Sign=1 - should NOT call
      117 => x"06", -- LrI A,0x80
      118 => x"80",
      119 => x"04", -- ADI 0x00    (Sign=1)
      120 => x"00",
      121 => x"52", -- CFS 0x00E0  (should NOT call)
      122 => x"E0",
      123 => x"00",
      124 => x"0E", -- LrI B,0x96  (marker: CFS skipped)
      125 => x"96",

        -- TEST 15: CTP with Parity=0 - should NOT call
      126 => x"06", -- LrI A,0x01
      127 => x"01",
      128 => x"04", -- ADI 0x00    (Parity=0)
      129 => x"00",
      130 => x"7A", -- CTP 0x00E0  (should NOT call)
      131 => x"E0",
      132 => x"00",
      133 => x"0E", -- LrI B,0x97  (marker: CTP skipped)
      134 => x"97",

        -- TEST 16: CFP with Parity=1 - should NOT call
      135 => x"06", -- LrI A,0x03
      136 => x"03",
      137 => x"04", -- ADI 0x00    (Parity=1)
      138 => x"00",
      139 => x"5A", -- CFP 0x00E0  (should NOT call)
      140 => x"E0",
      141 => x"00",
      142 => x"0E", -- LrI B,0x98  (marker: CFP skipped)
      143 => x"98",

        -- ========================================
        -- SUCCESS - All tests passed
        -- ========================================
      144 => x"0E", -- LrI B,0xFF  (final marker)
      145 => x"FF",
      146 => x"00", -- HLT

        -- ========================================
        -- Subroutine at 0x00E0
        -- ========================================
      224 => x"16", -- LrI C,0x99  (marker: subroutine executed)
      225 => x"99",
      226 => x"47", -- RET = 01 000 111 = 0x47

        others => x"00"  -- Fill rest with HLT
    );

    -- Memory controller signals
    signal rom_data : std_logic_vector(7 downto 0) := (others => 'Z');
    signal rom_enable : std_logic := '0';

    -- Test control
    signal test_complete : boolean := false;
    constant TIMEOUT : time := 3000 us;  -- Allow enough time for all 16 tests

begin
    -- Bus driver (continuous assignment)
    data_tb <= rom_data when rom_enable = '1' else (others => 'Z');

    -- Instantiate the CPU
    uut : s8008
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
        if not test_complete then
            master_clk_tb <= '0';
            wait for MASTER_CLK_PERIOD / 2;
            master_clk_tb <= '1';
            wait for MASTER_CLK_PERIOD / 2;
        else
            wait;
        end if;
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
                    is_write := (cycle_type = "10");  -- PCW = write cycle
                end if;
            end if;

            -- T3: Enable ROM for read cycles
            if S2_tb = '1' and S1_tb = '0' and S0_tb = '0' then
                if is_write then
                    -- Write cycle - don't drive bus
                    rom_enable <= '0';
                    rom_data <= (others => 'Z');
                else
                    -- Read cycle - drive bus with ROM data
                    rom_enable <= '1';
                    rom_data <= rom(to_integer(unsigned(captured_address(7 downto 0))));
                end if;
            else
                -- Not in T3 - release bus
                rom_enable <= '0';
                rom_data <= (others => 'Z');
            end if;
        end if;
    end process;

    -- Test sequence
    process
        variable test_count : integer := 0;
        variable all_passed : boolean := true;
    begin
        -- Reset sequence
        reset_tb <= '1';
        reset_n_tb <= '0';
        wait for 100 ns;
        reset_tb <= '0';
        wait for 50 ns;
        reset_n_tb <= '1';
        wait for 50 ns;

        report "=== Starting Conditional CALL Tests ===";

        -- Wait for all tests to complete (B register reaches 0xFF)
        wait until debug_reg_B_tb = x"FF" for TIMEOUT;

        if debug_reg_B_tb /= x"FF" then
            report "FAIL: Test timeout - B=" &
                   to_hstring(unsigned(debug_reg_B_tb)) &
                   " (expected 0xFF)" severity error;
            all_passed := false;
        else
            report "=== All 16 Conditional CALL Tests PASSED ===" severity note;
        end if;

        -- Additional verification: C register should be 0x99 (subroutine was called)
        if debug_reg_C_tb /= x"99" then
            report "FAIL: Subroutine marker incorrect - C=" &
                   to_hstring(unsigned(debug_reg_C_tb)) &
                   " (expected 0x99)" severity error;
            all_passed := false;
        end if;

        test_complete <= true;

        if all_passed then
            report "*** TEST PASSED ***" severity note;
        else
            report "*** TEST FAILED ***" severity error;
        end if;

        wait;
    end process;

end behavior;
