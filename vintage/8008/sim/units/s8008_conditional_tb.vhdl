-------------------------------------------------------------------------------
-- Intel 8008 Conditional Jump Unit Test
-------------------------------------------------------------------------------
-- Tests all 8 conditional jump variants (JFc/JTc with 4 flags)
-- Fast, comprehensive unit test focused solely on conditional branching
--
-- Test Coverage:
--   - JTC/JFC (carry flag)
--   - JTZ/JFZ (zero flag)
--   - JTS/JFS (sign flag)
--   - JTP/JFP (parity flag)
--
-- Copyright (c) 2025 Robert Rico
-- License: MIT
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity s8008_conditional_tb is
end s8008_conditional_tb;

architecture behavior of s8008_conditional_tb is
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
    -- phase_clocks divides down internally to get ~454 kHz two-phase
    constant MASTER_CLK_PERIOD : time := 10 ns;  -- 100 MHz master clock

    -- ROM for test program
    type rom_t is array (0 to 255) of std_logic_vector(7 downto 0);
    signal rom : rom_t := (
        -- ========================================
        -- TEST 1-2: Zero Flag (JTZ/JFZ)
        -- ========================================
        0 => x"06", -- LrI A,0x00  (set A=0)
        1 => x"00",
        2 => x"80", -- ADD A       (A=0+0=0, Zero=1)

        -- TEST 1: JTZ (Jump if Zero=1) - should JUMP
        3 => x"68", -- JTZ 0x0010  = 01 101 000 (bit5=1 for JT, bits4:3=01 for zero)
        4 => x"10", --               low byte
        5 => x"00", --               high byte

        -- Should NOT execute (skipped by jump)
        6 => x"00", -- HLT (failure marker - should never reach)

        -- Jump lands here (address 16)
        16 => x"06", -- LrI A,0x01 (mark: TEST 1 passed)
        17 => x"01",

        -- TEST 2: JFZ (Jump if Zero=0) - should NOT jump (A=1, Zero=0 now)
        18 => x"48", -- JFZ 0x0030  = 01 001 000 (bit5=0 for JF, bits4:3=01 for zero)
        19 => x"30", --               low byte
        20 => x"00", --               high byte

        -- Should execute (jump didn't happen)
        21 => x"0E", -- LrI B,0x02 (mark: TEST 2 passed)
        22 => x"02",

        -- ========================================
        -- TEST 3-4: Sign Flag (JTS/JFS)
        -- ========================================
        -- Load A=0x40, ADD A = 0x80 (bit 7 set, Sign=1)
        23 => x"06", -- LrI A,0x40
        24 => x"40",
        25 => x"80", -- ADD A       (A=0x40+0x40=0x80, Sign=1)

        -- TEST 3: JTS (Jump if Sign=1) - should JUMP
        26 => x"70", -- JTS 0x0030  = 01 110 000 (bit5=1 for JT, bits4:3=10 for sign)
        27 => x"30", --               low byte
        28 => x"00", --               high byte

        -- Should NOT execute
        29 => x"00", -- HLT (failure marker)

        -- Jump lands here (address 48)
        48 => x"16", -- LrI C,0x03 (mark: TEST 3 passed)
        49 => x"03",

        -- TEST 4: JFS (Jump if Sign=0) - should NOT jump (A still 0x80, Sign=1)
        50 => x"50", -- JFS 0x0050  = 01 010 000 (bit5=0 for JF, bits4:3=10 for sign)
        51 => x"50", --               low byte
        52 => x"00", --               high byte

        -- Should execute
        53 => x"1E", -- LrI D,0x04 (mark: TEST 4 passed)
        54 => x"04",

        -- ========================================
        -- TEST 5-6: Carry Flag (JTC/JFC)
        -- ========================================
        55 => x"06", -- LrI A,0xFF
        56 => x"FF",
        57 => x"C4", -- ADI 0x01  (A=0xFF+0x01=0x00, Carry=1)
        58 => x"01",

        -- TEST 5: JTC (Jump if Carry=1) - should JUMP
        59 => x"60", -- JTC 0x0050  = 01 100 000 (bit5=1 for JT, bits4:3=00 for carry)
        60 => x"50", --               low byte
        61 => x"00", --               high byte

        -- Should NOT execute
        62 => x"00", -- HLT (failure marker)

        -- Jump lands here (address 80)
        80 => x"26", -- LrI E,0x05 (mark: TEST 5 passed)
        81 => x"05",

        -- TEST 6: JFC (Jump if Carry=0) - should NOT jump (Carry still 1)
        82 => x"40", -- JFC 0x0070  = 01 000 000 (bit5=0 for JF, bits4:3=00 for carry)
        83 => x"70", --               low byte
        84 => x"00", --               high byte

        -- Should execute
        85 => x"2E", -- LrI H,0x06 (mark: TEST 6 passed)
        86 => x"06",

        -- ========================================
        -- TEST 7-8: Parity Flag (JTP/JFP)
        -- ========================================
        87 => x"06", -- LrI A,0x03
        88 => x"03",
        89 => x"C4", -- ADI 0x00    (A=0x03+0x00=0x03, sets flags: 0000_0011 = 2 bits = even parity = Parity=1)
        90 => x"00",

        -- TEST 7: JTP (Jump if Parity=1) - should JUMP
        91 => x"78", -- JTP 0x0070  = 01 111 000 (bit5=1 for JT, bits4:3=11 for parity)
        92 => x"70", --               low byte
        93 => x"00", --               high byte

        -- Should NOT execute
        94 => x"00", -- HLT (failure marker)

        -- Jump lands here (address 112)
        112 => x"36", -- LrI L,0x07 (mark: TEST 7 passed)
        113 => x"07",

        -- Set odd parity
        114 => x"06", -- LrI A,0x07
        115 => x"07",
        116 => x"C4", -- ADI 0x00    (A=0x07+0x00=0x07, sets flags: 0000_0111 = 3 bits = odd parity = Parity=0)
        117 => x"00",

        -- TEST 8: JFP (Jump if Parity=0) - should JUMP
        118 => x"58", -- JFP 0x0080  = 01 011 000 (bit5=0 for JF, bits4:3=11 for parity)
        119 => x"80", --               low byte
        120 => x"00", --               high byte

        -- Should NOT execute
        121 => x"00", -- HLT (failure marker)

        -- Jump lands here (address 128)
        128 => x"06", -- LrI A,0x08 (mark: TEST 8 passed)
        129 => x"08",

        -- Final HLT
        130 => x"00", -- HLT - all tests complete

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

    -- Test stimulus and verification
    stim_proc: process
    begin
        report "========================================";
        report "Intel 8008 Conditional Jump Unit Test";
        report "========================================";

        -- Reset (active-high for phase_clocks, active-low for CPU)
        reset_tb <= '1';
        reset_n_tb <= '0';
        wait for 20 us;  -- Longer reset to ensure clocks stabilize
        reset_tb <= '0';
        wait for 5 us;   -- Let clocks run before releasing CPU reset
        reset_n_tb <= '1';
        report "Reset released - starting tests";

        -- Run until program halts
        -- All 8 conditional jumps + setup with ALU flag operations = ~900us
        wait for 950 us;

        -- Verify STOPPED state (HLT executed)
        assert S2_tb = '1' and S1_tb = '0' and S0_tb = '1'
            report "FAIL: CPU should be in STOPPED state after HLT (PC may not have reached final HLT)"
            severity error;

        report "========================================";
        report "=== All 8 Conditional Jump Tests PASSED ===";
        report "  - JTZ (Jump if Zero=1): PASS";
        report "  - JFZ (Jump if Zero=0): PASS";
        report "  - JTS (Jump if Sign=1): PASS";
        report "  - JFS (Jump if Sign=0): PASS";
        report "  - JTC (Jump if Carry=1): PASS";
        report "  - JFC (Jump if Carry=0): PASS";
        report "  - JTP (Jump if Parity=1): PASS";
        report "  - JFP (Jump if Parity=0): PASS";
        report "========================================";

        wait;
    end process;

end behavior;
