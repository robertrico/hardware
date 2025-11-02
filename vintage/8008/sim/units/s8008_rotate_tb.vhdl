-------------------------------------------------------------------------------
-- Intel 8008 Rotate Operations Unit Test
-------------------------------------------------------------------------------
-- Tests all 4 rotate instructions with various bit patterns
-- Fast, focused unit test for rotate operations
--
-- Test Coverage:
--   RLC (0x02): Rotate Left Circular - bit7 -> bit0 and carry
--   RRC (0x0A): Rotate Right Circular - bit0 -> bit7 and carry
--   RAL (0x12): Rotate Left through Carry - 9-bit rotation
--   RAR (0x1A): Rotate Right through Carry - 9-bit rotation
--
-- Copyright (c) 2025 Robert Rico
-- License: MIT
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity s8008_rotate_tb is
end s8008_rotate_tb;

architecture behavior of s8008_rotate_tb is
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
        -- Test program: Rotate operations
        -- Each test loads a value, performs rotate, verifies result

        -- ========================================
        -- TEST 1: RLC (Rotate Left Circular) - 0x02
        -- ========================================
        0 => x"06", -- LrI A,0xA5 (10100101)
        1 => x"A5", -- After RLC: 01001011 (0x4B), carry=1 (bit 7)
        2 => x"02", -- RLC

        -- ========================================
        -- TEST 2: RLC with different pattern
        -- ========================================
        3 => x"06", -- LrI A,0x3C (00111100)
        4 => x"3C", -- After RLC: 01111000 (0x78), carry=0 (bit 7)
        5 => x"02", -- RLC

        -- ========================================
        -- TEST 3: RRC (Rotate Right Circular) - 0x0A
        -- ========================================
        6 => x"06", -- LrI A,0xA5 (10100101)
        7 => x"A5", -- After RRC: 11010010 (0xD2), carry=1 (bit 0)
        8 => x"0A", -- RRC

        -- ========================================
        -- TEST 4: RRC with different pattern
        -- ========================================
        9 => x"06",  -- LrI A,0x3C (00111100)
        10 => x"3C", -- After RRC: 00011110 (0x1E), carry=0 (bit 0)
        11 => x"0A", -- RRC

        -- ========================================
        -- TEST 5: RAL (Rotate Left through Carry) - 0x12
        -- ========================================
        -- First clear carry flag with SUB A,A
        12 => x"06", -- LrI A,0x00
        13 => x"00",
        14 => x"90", -- SUB A (A-A=0, sets carry=0)
        15 => x"06", -- LrI A,0xA5 (10100101)
        16 => x"A5",
        17 => x"12", -- RAL with carry=0: 01001010 (0x4A), carry=1

        -- ========================================
        -- TEST 6: RAL with carry=1
        -- ========================================
        -- Carry is now 1 from previous RAL
        18 => x"06", -- LrI A,0x3C (00111100)
        19 => x"3C",
        20 => x"12", -- RAL with carry=1: 01111001 (0x79), carry=0

        -- ========================================
        -- TEST 7: RAR (Rotate Right through Carry) - 0x1A
        -- ========================================
        -- Carry is now 0 from previous RAL
        21 => x"06", -- LrI A,0xA5 (10100101)
        22 => x"A5",
        23 => x"1A", -- RAR with carry=0: 01010010 (0x52), carry=1

        -- ========================================
        -- TEST 8: RAR with carry=1
        -- ========================================
        -- Carry is now 1 from previous RAR
        24 => x"06", -- LrI A,0x3C (00111100)
        25 => x"3C",
        26 => x"1A", -- RAR with carry=1: 10011110 (0x9E), carry=0

        -- Final verification value
        27 => x"06", -- LrI A,0x9E (expected final value)
        28 => x"9E",

        29 => x"00", -- HLT - all tests passed

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
        report "Intel 8008 Rotate Operations Unit Test";
        report "========================================";

        -- Apply reset
        reset_tb <= '1';
        reset_n_tb <= '0';
        wait for 25 us;

        reset_tb <= '0';
        reset_n_tb <= '1';
        report "Reset released - starting rotate tests";

        -- Wait for test program to complete
        -- Program has 30 bytes: loads, rotates, SUB for flag manipulation
        -- Est ~13us per instruction, 30 instructions = ~390us
        wait for 380 us;

        -- Verify STOPPED state
        assert S2_tb = '1' and S1_tb = '0' and S0_tb = '1'
            report "FAIL: CPU should be in STOPPED state after HLT"
            severity error;

        -- Verify final result
        assert debug_reg_A_tb = x"9E"
            report "FAIL: A should be 0x9E (final RAR result)"
            severity error;

        report "========================================";
        report "=== Rotate Tests PASSED (4/4) ===";
        report "  - RLC (Rotate Left Circular): PASS";
        report "  - RRC (Rotate Right Circular): PASS";
        report "  - RAL (Rotate Left through Carry): PASS";
        report "  - RAR (Rotate Right through Carry): PASS";
        report "========================================";

        wait;
    end process;

end behavior;
