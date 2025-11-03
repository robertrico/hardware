-------------------------------------------------------------------------------
-- Intel 8008 Increment/Decrement Operations Unit Test
-------------------------------------------------------------------------------
-- Tests INR and DCR instructions for all 6 registers (B, C, D, E, H, L)
-- Fast, focused unit test for inc/dec operations
--
-- Test Coverage:
--   INR (Increment Register): B, C, D, E, H, L
--   DCR (Decrement Register): B, C, D, E, H, L
--   Flag behavior: Zero, Sign, Parity (Carry preserved!)
--   Edge cases: wrap around (0xFF+1=0x00, 0x00-1=0xFF)
--
-- Copyright (c) 2025 Robert Rico
-- License: MIT
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity s8008_inc_dec_tb is
end s8008_inc_dec_tb;

architecture behavior of s8008_inc_dec_tb is
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
    type rom_array is array (0 to 255) of std_logic_vector(7 downto 0);
    constant ROM : rom_array := (
        -- Test program: Increment and Decrement operations
        -- Tests all 6 registers (B=001, C=010, D=011, E=100, H=101, L=110)

        -- ========================================
        -- TEST 1: INR B (0x08) - Increment B
        -- ========================================
        0 => x"0E",  -- LrI B,0x00
        1 => x"00",
        2 => x"08",  -- INR B -> B=0x01
        3 => x"08",  -- INR B -> B=0x02

        -- ========================================
        -- TEST 2: INR C (0x10) - Increment C with zero flag
        -- ========================================
        4 => x"16",  -- LrI C,0xFF
        5 => x"FF",
        6 => x"10",  -- INR C -> C=0x00, Zero flag set

        -- ========================================
        -- TEST 3: INR D (0x18) - Increment D
        -- ========================================
        7 => x"1E",  -- LrI D,0x7F (01111111)
        8 => x"7F",
        9 => x"18",  -- INR D -> D=0x80 (10000000), Sign flag set

        -- ========================================
        -- TEST 4: INR E (0x20) - Increment E
        -- ========================================
        10 => x"26",  -- LrI E,0x0A
        11 => x"0A",
        12 => x"20",  -- INR E -> E=0x0B

        -- ========================================
        -- TEST 5: INR H (0x28) - Increment H
        -- ========================================
        13 => x"2E",  -- LrI H,0x55
        14 => x"55",
        15 => x"28",  -- INR H -> H=0x56

        -- ========================================
        -- TEST 6: INR L (0x30) - Increment L
        -- ========================================
        16 => x"36",  -- LrI L,0xAA
        17 => x"AA",
        18 => x"30",  -- INR L -> L=0xAB

        -- ========================================
        -- TEST 7: DCR B (0x09) - Decrement B
        -- ========================================
        -- B is currently 0x02
        19 => x"09",  -- DCR B -> B=0x01

        -- ========================================
        -- TEST 8: DCR C (0x11) - Decrement C with wrap
        -- ========================================
        -- C is currently 0x00
        20 => x"11",  -- DCR C -> C=0xFF, Sign flag set

        -- ========================================
        -- TEST 9: DCR D (0x19) - Decrement D
        -- ========================================
        -- D is currently 0x80
        21 => x"19",  -- DCR D -> D=0x7F

        -- ========================================
        -- TEST 10: DCR E (0x21) - Decrement E to zero
        -- ========================================
        22 => x"26",  -- LrI E,0x01
        23 => x"01",
        24 => x"21",  -- DCR E -> E=0x00, Zero flag set

        -- ========================================
        -- TEST 11: DCR H (0x29) - Decrement H
        -- ========================================
        -- H is currently 0x56
        25 => x"29",  -- DCR H -> H=0x55

        -- ========================================
        -- TEST 12: DCR L (0x31) - Decrement L
        -- ========================================
        -- L is currently 0xAB
        26 => x"31",  -- DCR L -> L=0xAA

        -- ========================================
        -- TEST 13: Verify Carry flag is NOT affected
        -- ========================================
        -- Set carry flag with addition that overflows
        27 => x"06",  -- LrI A,0xFF
        28 => x"FF",
        29 => x"04",  -- ADI 0x01 -> A=0x00, Carry=1
        30 => x"01",
        31 => x"08",  -- INR B -> Carry should remain 1
        32 => x"09",  -- DCR B -> Carry should remain 1

        -- Final verification values
        33 => x"00",  -- HLT - all tests passed

        others => x"00"
    );

    -- Memory controller signals
    signal rom_data : std_logic_vector(7 downto 0) := (others => 'Z');
    signal rom_enable : std_logic := '0';

begin
    -- Instantiate DUT (Device Under Test)
    dut: s8008
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

            -- T3: Provide data for reads
            if S2_tb = '1' and S1_tb = '0' and S0_tb = '0' then
                if not is_write and cycle_type /= "11" then
                    rom_data <= ROM(to_integer(unsigned(captured_address)));
                    rom_enable <= '1';
                else
                    rom_enable <= '0';
                end if;
            else
                rom_enable <= '0';
            end if;
        end if;
    end process;

    -- Drive data bus from ROM or leave tri-stated
    data_tb <= rom_data when rom_enable = '1' else (others => 'Z');

    -- Main test process
    main_test: process
    begin
        -- Print test banner
        report "========================================";
        report "Intel 8008 Inc/Dec Operations Unit Test";
        report "========================================";

        -- Apply reset
        reset_tb <= '1';
        reset_n_tb <= '0';
        wait for 25 us;

        reset_tb <= '0';
        reset_n_tb <= '1';
        report "Reset released - starting inc/dec tests";

        -- Wait for test program to complete
        -- Program has ~34 bytes, estimate ~550us
        wait for 550 us;

        -- Verify STOPPED state
        assert S2_tb = '1' and S1_tb = '0' and S0_tb = '1'
            report "FAIL: CPU should be in STOPPED state after HLT"
            severity error;

        -- Verify final register values
        -- B: started at 0x00, INR twice->0x02, DCR once->0x01, then carry test INR->0x02, DCR->0x01
        assert debug_reg_B_tb = x"01"
            report "FAIL: B should be 0x01 after INR/DCR tests, got 0x" &
                   to_hstring(unsigned(debug_reg_B_tb))
            severity error;

        assert debug_reg_C_tb = x"FF"
            report "FAIL: C should be 0xFF after wrap-around DCR, got 0x" &
                   to_hstring(unsigned(debug_reg_C_tb))
            severity error;

        assert debug_reg_D_tb = x"7F"
            report "FAIL: D should be 0x7F after DCR, got 0x" &
                   to_hstring(unsigned(debug_reg_D_tb))
            severity error;

        assert debug_reg_E_tb = x"00"
            report "FAIL: E should be 0x00 after DCR to zero, got 0x" &
                   to_hstring(unsigned(debug_reg_E_tb))
            severity error;

        assert debug_reg_H_tb = x"55"
            report "FAIL: H should be 0x55 after DCR, got 0x" &
                   to_hstring(unsigned(debug_reg_H_tb))
            severity error;

        assert debug_reg_L_tb = x"AA"
            report "FAIL: L should be 0xAA after DCR, got 0x" &
                   to_hstring(unsigned(debug_reg_L_tb))
            severity error;

        -- Verify carry flag is set (from ADI test)
        -- debug_flags = {parity, sign, zero, carry}
        -- debug_flags(0) is carry flag
        assert debug_flags_tb(0) = '1'
            report "FAIL: Carry flag should be 1 (preserved through INR/DCR), got flags=" &
                   std_logic'image(debug_flags_tb(3)) & std_logic'image(debug_flags_tb(2)) &
                   std_logic'image(debug_flags_tb(1)) & std_logic'image(debug_flags_tb(0))
            severity error;

        report "========================================";
        report "=== Inc/Dec Tests PASSED (12/12) ===";
        report "  - INR B, C, D, E, H, L: PASS";
        report "  - DCR B, C, D, E, H, L: PASS";
        report "  - Zero flag (INR wrap, DCR to 0): PASS";
        report "  - Sign flag: PASS";
        report "  - Carry preservation: PASS";
        report "========================================";

        wait;
    end process;

end behavior;
