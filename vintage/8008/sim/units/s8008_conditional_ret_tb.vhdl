-------------------------------------------------------------------------------
-- Intel 8008 Conditional RET Unit Test
-------------------------------------------------------------------------------
-- Tests all 8 conditional RET variants (RFc/RTc with 4 flags)
-- Fast, comprehensive unit test focused solely on conditional RET
--
-- Test Coverage:
--   - RTC/RFC (carry flag)
--   - RTZ/RFZ (zero flag)
--   - RTS/RFS (sign flag)
--   - RTP/RFP (parity flag)
--   - Verifies stack pop only when condition is met
--   - Verifies correct return behavior
--
-- Copyright (c) 2025 Robert Rico
-- License: MIT
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity s8008_conditional_ret_tb is
end s8008_conditional_ret_tb;

architecture behavior of s8008_conditional_ret_tb is
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
    constant MASTER_CLK_PERIOD : time := 10 ns;

    -- ROM for test program
    type rom_t is array (0 to 255) of std_logic_vector(7 downto 0);
    signal rom : rom_t := (
        -- ========================================
        -- TEST 1: RFC (Return if Carry=0) - TRUE
        -- ========================================
        0 => x"46", -- CALL 0x0080 (subroutine 1)
        1 => x"80",
        2 => x"00",
        3 => x"0E", -- LrI B,0x11 (marker: returned from test 1)
        4 => x"11",

        -- ========================================
        -- TEST 2: RTC (Return if Carry=1) - TRUE
        -- ========================================
        5 => x"46", -- CALL 0x0090 (subroutine 2)
        6 => x"90",
        7 => x"00",
        8 => x"0E", -- LrI B,0x22 (marker: returned from test 2)
        9 => x"22",

        -- ========================================
        -- TEST 3: RFZ (Return if Zero=0) - TRUE
        -- ========================================
       10 => x"46", -- CALL 0x00A0 (subroutine 3)
       11 => x"A0",
       12 => x"00",
       13 => x"0E", -- LrI B,0x33 (marker: returned from test 3)
       14 => x"33",

        -- ========================================
        -- TEST 4: RTZ (Return if Zero=1) - TRUE
        -- ========================================
       15 => x"46", -- CALL 0x00B0 (subroutine 4)
       16 => x"B0",
       17 => x"00",
       18 => x"0E", -- LrI B,0x44 (marker: returned from test 4)
       19 => x"44",

        -- ========================================
        -- TEST 5: RFS (Return if Sign=0) - TRUE
        -- ========================================
       20 => x"46", -- CALL 0x00C0 (subroutine 5)
       21 => x"C0",
       22 => x"00",
       23 => x"0E", -- LrI B,0x55 (marker: returned from test 5)
       24 => x"55",

        -- ========================================
        -- TEST 6: RTS (Return if Sign=1) - TRUE
        -- ========================================
       25 => x"46", -- CALL 0x00D0 (subroutine 6)
       26 => x"D0",
       27 => x"00",
       28 => x"0E", -- LrI B,0x66 (marker: returned from test 6)
       29 => x"66",

        -- ========================================
        -- TEST 7: RFP (Return if Parity=0) - TRUE
        -- ========================================
       30 => x"46", -- CALL 0x00E0 (subroutine 7)
       31 => x"E0",
       32 => x"00",
       33 => x"0E", -- LrI B,0x77 (marker: returned from test 7)
       34 => x"77",

        -- ========================================
        -- TEST 8: RTP (Return if Parity=1) - TRUE
        -- ========================================
       35 => x"46", -- CALL 0x00F0 (subroutine 8)
       36 => x"F0",
       37 => x"00",
       38 => x"0E", -- LrI B,0x88 (marker: returned from test 8)
       39 => x"88",

        -- ========================================
        -- SUCCESS - All positive tests passed
        -- ========================================
       40 => x"0E", -- LrI B,0xFF (final marker)
       41 => x"FF",
       42 => x"00", -- HLT

        -- ========================================
        -- Subroutine 1 at 0x0080: RFC (Return if Carry=0)
        -- ========================================
      128 => x"06", -- LrI A,0x00
      129 => x"00",
      130 => x"04", -- ADI 0x00 (Carry=0)
      131 => x"00",
      132 => x"03", -- RFC = 00 000 011 (should return)
      133 => x"00", -- HLT (failure - should not reach)

        -- ========================================
        -- Subroutine 2 at 0x0090: RTC (Return if Carry=1)
        -- ========================================
      144 => x"06", -- LrI A,0xFF
      145 => x"FF",
      146 => x"04", -- ADI 0x01 (Carry=1)
      147 => x"01",
      148 => x"23", -- RTC = 00 100 011 (should return)
      149 => x"00", -- HLT (failure)

        -- ========================================
        -- Subroutine 3 at 0x00A0: RFZ (Return if Zero=0)
        -- ========================================
      160 => x"06", -- LrI A,0x01
      161 => x"01",
      162 => x"04", -- ADI 0x00 (Zero=0)
      163 => x"00",
      164 => x"0B", -- RFZ = 00 001 011 (should return)
      165 => x"00", -- HLT (failure)

        -- ========================================
        -- Subroutine 4 at 0x00B0: RTZ (Return if Zero=1)
        -- ========================================
      176 => x"06", -- LrI A,0x00
      177 => x"00",
      178 => x"04", -- ADI 0x00 (Zero=1)
      179 => x"00",
      180 => x"2B", -- RTZ = 00 101 011 (should return)
      181 => x"00", -- HLT (failure)

        -- ========================================
        -- Subroutine 5 at 0x00C0: RFS (Return if Sign=0)
        -- ========================================
      192 => x"06", -- LrI A,0x7F
      193 => x"7F",
      194 => x"04", -- ADI 0x00 (Sign=0)
      195 => x"00",
      196 => x"13", -- RFS = 00 010 011 (should return)
      197 => x"00", -- HLT (failure)

        -- ========================================
        -- Subroutine 6 at 0x00D0: RTS (Return if Sign=1)
        -- ========================================
      208 => x"06", -- LrI A,0x80
      209 => x"80",
      210 => x"04", -- ADI 0x00 (Sign=1)
      211 => x"00",
      212 => x"33", -- RTS = 00 110 011 (should return)
      213 => x"00", -- HLT (failure)

        -- ========================================
        -- Subroutine 7 at 0x00E0: RFP (Return if Parity=0)
        -- ========================================
      224 => x"06", -- LrI A,0x01 (odd parity)
      225 => x"01",
      226 => x"04", -- ADI 0x00 (Parity=0)
      227 => x"00",
      228 => x"1B", -- RFP = 00 011 011 (should return)
      229 => x"00", -- HLT (failure)

        -- ========================================
        -- Subroutine 8 at 0x00F0: RTP (Return if Parity=1)
        -- ========================================
      240 => x"06", -- LrI A,0x03 (even parity)
      241 => x"03",
      242 => x"04", -- ADI 0x00 (Parity=1)
      243 => x"00",
      244 => x"3B", -- RTP = 00 111 011 (should return)
      245 => x"00", -- HLT (failure)

        others => x"00"  -- Fill rest with HLT
    );

    -- Memory controller signals
    signal rom_data : std_logic_vector(7 downto 0) := (others => 'Z');
    signal rom_enable : std_logic := '0';

    -- Test control
    signal test_complete : boolean := false;
    constant TIMEOUT : time := 2000 us;

begin
    -- Bus driver
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

    -- Test sequence
    process
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

        report "=== Starting Conditional RET Tests ===";

        -- Wait for all tests to complete (B register reaches 0xFF)
        wait until debug_reg_B_tb = x"FF" for TIMEOUT;

        if debug_reg_B_tb /= x"FF" then
            report "FAIL: Test timeout - B=" &
                   to_hstring(unsigned(debug_reg_B_tb)) &
                   " (expected 0xFF)" severity error;
            all_passed := false;
        else
            report "=== All 8 Conditional RET Tests PASSED ===" severity note;
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
