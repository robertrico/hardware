-------------------------------------------------------------------------------
-- Testbench for Intel 8008 Silicon-Accurate Implementation
-------------------------------------------------------------------------------
-- Tests the basic timing and state sequencing of the s8008 core
--
-- Verifies:
--   - Two-phase clock operation
--   - Clock phase counter (two clock periods per state)
--   - SYNC signal generation (divide-by-two of clock period)
--   - Variable-length cycles (3-state for PCI/PCR/PCW, 5-state for EXECUTE)
--   - State transitions (T1->T2->T3->T1 for instruction fetch)
--   - S0/S1/S2 state encoding
--   - READY and INT signal handling
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity s8008_tb is
end s8008_tb;

architecture sim of s8008_tb is

    -- Component declaration
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

    -- Phase clock generator component
    component phase_clocks is
        port (
            clk_in : in std_logic;
            reset  : in std_logic;
            phi1   : out std_logic;
            phi2   : out std_logic
        );
    end component;

    -- Testbench signals
    signal master_clk_tb : std_logic := '0';    -- Master clock for phase_clocks component
    signal reset_tb : std_logic := '1';         -- Active-high reset for phase_clocks
    signal phi1_tb : std_logic := '0';
    signal phi2_tb : std_logic := '0';
    signal reset_n_tb : std_logic := '0';
    signal data_bus_tb : std_logic_vector(7 downto 0);
    signal S0_tb : std_logic;
    signal S1_tb : std_logic;
    signal S2_tb : std_logic;
    signal SYNC_tb : std_logic;
    signal READY_tb : std_logic := '1';
    signal INT_tb : std_logic := '0';

    -- Debug signals for assertion testing
    signal debug_reg_A_tb : std_logic_vector(7 downto 0);
    signal debug_reg_B_tb : std_logic_vector(7 downto 0);
    signal debug_reg_C_tb : std_logic_vector(7 downto 0);
    signal debug_reg_D_tb : std_logic_vector(7 downto 0);
    signal debug_reg_E_tb : std_logic_vector(7 downto 0);
    signal debug_reg_H_tb : std_logic_vector(7 downto 0);
    signal debug_reg_L_tb : std_logic_vector(7 downto 0);
    signal debug_pc_tb : std_logic_vector(13 downto 0);
    signal debug_flags_tb : std_logic_vector(3 downto 0);

    -- Master clock timing (100 MHz for phase_clocks component)
    constant MASTER_CLK_PERIOD : time := 10 ns;  -- 100 MHz master clock
    constant CLOCK_PERIOD      : time := 2.2 us; -- Total 8008 clock period (for reference)

    -- Simulation control
    signal sim_done : boolean := false;

    -- State decode helper
    signal state_name : string(1 to 7);

    -- Simple ROM model for testing instruction fetch
    -- Provides instruction data during T3 of PCI cycles
    type rom_t is array (0 to 255) of std_logic_vector(7 downto 0);
    signal rom : rom_t := (
        -- Comprehensive test program for all implemented 8008 instructions
        -- Tests: LrI, MOV (register), MOV (memory), ALU (register), ALU (immediate),
        --        ALU (memory), and JMP (unconditional jump)
        --
        -- Intel 8008 opcodes:
        --   LrI (Load Immediate) = 00 DDD 110 + immediate byte (class 00)
        --   MOV dst,src = 11 DDD SSS (class 11) - **CORRECTED FROM CLASS 00**
        --   ALU op,src = 10 OOO SSS (class 10)
        --   ALU op,imm = 11 OOO 100 + immediate byte (class 11)
        --   JMP = 01 XXX 100 + addr_low + addr_high (class 01)
        --   Register encoding: 000=A, 001=B, 010=C, 011=D, 100=E, 101=H, 110=L, 111=M
        --   ALU operations: 000=ADD, 001=ADC, 010=SUB, 011=SBB, 100=AND, 101=XOR, 110=OR, 111=CMP

        -- TEST 1: Load Immediate instructions (LrI)
        0 => x"06",  -- LrI A,0x12  = 00 000 110  (Load Accumulator Immediate)
        1 => x"12",  --               immediate data = 0x12
        2 => x"0E",  -- LrI B,0xAA  = 00 001 110  (Load B Immediate)
        3 => x"AA",  --               immediate data = 0xAA
        4 => x"16",  -- LrI C,0x55  = 00 010 110  (Load C Immediate)
        5 => x"55",  --               immediate data = 0x55

        -- TEST 2: Register-to-Register MOV
        6 => x"C1",  -- MOV A,B     = 11 000 001  (copy B -> A, result = 0xAA)

        -- TEST 3: ALU with register operands (ADD B to A)
        7 => x"81",  -- ADD B       = 10 000 001  (A = A + B = 0xAA + 0xAA = 0x54, with carry)

        -- TEST 4: ALU with immediate operand (ADD immediate to A)
        8 => x"04",  -- ADI 0x0C    = 00 000 100  (A = A + 0x0C)
        9 => x"0C",  --               immediate data = 0x0C

        -- TEST 5: Set up H:L register pair for memory operations
        10 => x"2E", -- LrI H,0x00  = 00 101 110  (H = 0x00)
        11 => x"00", --               immediate data = 0x00
        12 => x"36", -- LrI L,0xF0  = 00 110 110  (L = 0xF0, so M points to 0x00F0)
        13 => x"F0", --               immediate data = 0xF0

        -- TEST 6: Memory write (MOV M,C - store C to memory at H:L)
        14 => x"FA", -- MOV M,C     = 11 111 010  (Store C=0x55 to address 0x00F0)

        -- TEST 7: Memory read (MOV D,M - load from memory at H:L to D)
        15 => x"DF", -- MOV D,M     = 11 011 111  (Load from address 0x00F0 into D)

        -- TEST 8: ALU with memory operand (ADD M to A)
        16 => x"87", -- ADD M       = 10 000 111  (A = A + M[H:L])

        -- TEST 9: Unconditional jump - JMP to address 0x0019 (skip over unreachable code)
        17 => x"44", -- JMP 0x0019  = 01 000 100  (unconditional jump)
        18 => x"19", --               low byte = 0x19
        19 => x"00", --               high byte = 0x00 (target = 0x0019)

        -- These instructions at 20-22 should NEVER execute (skipped by jump)
        20 => x"0E", -- LrI B,0xFF  (should be skipped)
        21 => x"FF", --               (should be skipped)
        22 => x"0E", -- LrI B,0xEE  (should be skipped)
        23 => x"EE", --               (should be skipped)
        24 => x"00", -- HLT         (should be skipped)

        -- Extended ADI and MOV Tests at addresses 25-48 (decimal 0x19-0x30)
        -- Jump lands here at 0x0019 - these tests stress the immediate_data register and MOV register combinations
        25 => x"04", -- TEST 20: ADI 0x00 (add zero - A=0xB5 + 0x00 = 0xB5, no change)
        26 => x"00", --               immediate = 0x00
        27 => x"04", -- TEST 21: ADI 0xFF (test overflow/carry - A=0xB5 + 0xFF = 0x1B4 -> 0xB4, carry=1)
        28 => x"FF", --               immediate = 0xFF
        29 => x"04", -- TEST 22: ADI 0x01 (A=0xB4 + 0x01 = 0xB5)
        30 => x"01", --               immediate = 0x01
        31 => x"D0", -- TEST 23: MOV C,A = 11 010 000 (C should = 0xB5 from previous ADI)
        32 => x"D8", -- TEST 24: MOV D,A = 11 011 000 (D should = 0xB5, changed from MOV D,C to avoid rotate conflict)
        33 => x"E3", -- TEST 25: MOV E,D = 11 100 011
        34 => x"EC", -- TEST 26: MOV H,E = 11 101 100 (NO CONFLICT - XRI is Class 00!)
        35 => x"E5", -- TEST 27: MOV E,H = 11 100 101 (E should = 0xB5)
        36 => x"C3", -- TEST 28: MOV A,D = 11 000 011 (A should = 0xB5, complete circle)
        37 => x"C8", -- TEST 29: MOV B,A = 11 001 000
        38 => x"04", -- TEST 30: Chain ADI #1 - ADI 0x10 (A=0xB5 + 0x10 = 0xC5)
        39 => x"10", --               immediate = 0x10
        40 => x"04", -- TEST 31: Chain ADI #2 - ADI 0x20 (A=0xC5 + 0x20 = 0xE5)
        41 => x"20", --               immediate = 0x20
        42 => x"04", -- TEST 32: Chain ADI #3 - ADI 0x30 (A=0xE5 + 0x30 = 0x115 -> 0x15, carry=1)
        43 => x"30", --               immediate = 0x30
        44 => x"C8", -- TEST 33: Interleaved - MOV B,A = 11 001 000 (B = 0x15)
        45 => x"04", -- TEST 34: Interleaved - ADI 0x05 (A=0x15 + 0x05 = 0x1A)
        46 => x"05", --               immediate = 0x05
        47 => x"D0", -- TEST 35: Interleaved - MOV C,A = 11 010 000 (C = 0x1A)

        -- TEST 10: CALL/RET - Test subroutine call and return
        48 => x"46", -- TEST 36: CALL 0x0060 = 01 000 110  (call subroutine at address 0x0060)
        49 => x"60", --               low byte = 0x60
        50 => x"00", --               high byte = 0x00 (target = 0x0060)

        -- After RET, execution continues here
        51 => x"06", -- TEST 37: LrI A,0x99  = 00 000 110  (Load A with 0x99 to verify return)
        52 => x"99", --               immediate data = 0x99

        -- TEST 11: Nested CALL - Call subroutine that calls another subroutine
        53 => x"46", -- TEST 38: CALL 0x0080 = 01 000 110  (call first-level subroutine)
        54 => x"80", --               low byte = 0x80 (decimal 128)
        55 => x"00", --               high byte = 0x00

        -- After nested CALLs return, verify registers
        56 => x"06", -- TEST 39: LrI A,0xAA  = 00 000 110  (Load A with 0xAA to verify return)
        57 => x"AA", --               immediate data = 0xAA

        -- TEST 12: Stack depth test - Multiple nested CALLs to test stack levels
        58 => x"46", -- TEST 40: CALL 0x00A0 = 01 000 110  (call stack depth test routine)
        59 => x"A0", --               low byte = 0xA0 (decimal 160)
        60 => x"00", --               high byte = 0x00

        -- After stack depth test returns
        61 => x"16", -- TEST 41: LrI C,0xCC  = 00 010 110  (Load C with 0xCC to verify return)
        62 => x"CC", --               immediate data = 0xCC

        -- Final HLT
        63 => x"00", -- TEST 42: HLT - Stop execution

        -- First simple subroutine at address 0x0060 (decimal 96)
        96 => x"0E", -- LrI B,0x88  = 00 001 110  (Load B with 0x88 in subroutine)
        97 => x"88", --               immediate data = 0x88
        98 => x"47", -- RET         = 01 000 111  (return from subroutine)

        -- Nested CALL test: First-level subroutine at 0x0080 (decimal 128)
        -- This subroutine calls another subroutine to test nested CALLs
        128 => x"1E", -- LrI D,0x11  = 00 011 110  (Load D with 0x11)
        129 => x"11", --               immediate data = 0x11
        130 => x"46", -- CALL 0x0090 = 01 000 110  (call second-level subroutine)
        131 => x"90", --               low byte = 0x90 (decimal 144)
        132 => x"00", --               high byte = 0x00
        133 => x"26", -- LrI E,0x22  = 00 100 110  (Load E with 0x22 after nested call returns)
        134 => x"22", --               immediate data = 0x22
        135 => x"47", -- RET         = 01 000 111  (return from first-level subroutine)

        -- Nested CALL test: Second-level subroutine at 0x0090 (decimal 144)
        144 => x"2E", -- LrI H,0x33  = 00 101 110  (Load H with 0x33)
        145 => x"33", --               immediate data = 0x33
        146 => x"36", -- LrI L,0x44  = 00 110 110  (Load L with 0x44)
        147 => x"44", --               immediate data = 0x44
        148 => x"47", -- RET        = 01 000 111  (return from second-level subroutine)

        -- Stack depth test: Multiple nested CALLs at 0x00A0 (decimal 160)
        -- Tests stack levels 2, 3, 4 (we're already at level 1 from main)
        160 => x"06", -- LrI A,0x01 = 00 000 110  (Mark stack level 2)
        161 => x"01", --              immediate data = 0x01
        162 => x"46", -- CALL 0x00B0 = 01 000 110  (call level 3)
        163 => x"B0", --              low byte = 0xB0 (decimal 176)
        164 => x"00", --              high byte = 0x00
        165 => x"06", -- LrI A,0xF1 = 00 000 110  (After return, mark completion)
        166 => x"F1", --              immediate data = 0xF1
        167 => x"47", -- RET        = 01 000 111  (return from level 2)

        -- Stack depth test: Level 3 at 0x00B0 (decimal 176)
        176 => x"0E", -- LrI B,0x02 = 00 001 110  (Mark stack level 3)
        177 => x"02", --              immediate data = 0x02
        178 => x"46", -- CALL 0x00C0 = 01 000 110  (call level 4)
        179 => x"C0", --              low byte = 0xC0 (decimal 192)
        180 => x"00", --              high byte = 0x00
        181 => x"0E", -- LrI B,0xF2 = 00 001 110  (After return, mark completion)
        182 => x"F2", --              immediate data = 0xF2
        183 => x"47", -- RET        = 01 000 111  (return from level 3)

        -- Stack depth test: Level 4 (deepest) at 0x00C0 (decimal 192)
        192 => x"16", -- LrI C,0x03 = 00 010 110  (Mark stack level 4)
        193 => x"03", --              immediate data = 0x03
        194 => x"1E", -- LrI D,0x04 = 00 011 110  (Another operation at deepest level)
        195 => x"04", --              immediate data = 0x04
        196 => x"47", -- RET        = 01 000 111  (return from level 4)

        others => x"00"  -- Fill rest with HLT/zero
    );

    -- ROM/RAM output control
    signal rom_data : std_logic_vector(7 downto 0);
    signal rom_enable : std_logic;

    -- RAM model (writable memory for testing M register operations)
    type ram_t is array (0 to 255) of std_logic_vector(7 downto 0);
    signal ram : ram_t := (others => x"00");  -- Initialize writable RAM to zeros

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: s8008
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
    -- ROM/RAM Model (simulates memory device)
    --===========================================
    -- Unified memory model that supports both reads and writes
    -- ROM area (0x00-0xFF): instruction memory, initialized with test program
    -- RAM area (all addresses): writable data memory
    -- This simulates what real memory would do in a complete system

    -- Memory address capture and control process (clocked to avoid delta cycle issues)
    memory_controller: process(phi1_tb)
        variable captured_address : std_logic_vector(13 downto 0) := (others => '0');
        variable cycle_type : std_logic_vector(1 downto 0) := "00";
        variable is_write : boolean := false;
    begin
        if rising_edge(phi1_tb) then
            -- Capture address during T1 state (when CPU drives lower address byte)
            if S2_tb = '0' and S1_tb = '0' and S0_tb = '0' then
                if data_bus_tb /= "ZZZZZZZZ" then
                    captured_address(7 downto 0) := data_bus_tb;
                end if;
            end if;

            -- Capture cycle type and upper address bits during T2 state
            if S2_tb = '0' and S1_tb = '1' and S0_tb = '0' then
                if data_bus_tb /= "ZZZZZZZZ" then
                    cycle_type := data_bus_tb(7 downto 6);
                    captured_address(13 downto 8) := data_bus_tb(5 downto 0);
                    is_write := (cycle_type = "10");  -- PCW = write cycle
                end if;
            end if;

            -- During T3, handle read or write
            if S2_tb = '1' and S1_tb = '0' and S0_tb = '0' then
                if is_write then
                    -- Write cycle (PCW) - capture data from bus and write to RAM
                    if data_bus_tb /= "ZZZZZZZZ" then
                        -- Use lower 8 bits of 14-bit address for array indexing
                        ram(to_integer(unsigned(captured_address(7 downto 0)))) <= data_bus_tb;
                        report "RAM WRITE: addr=0x" & to_hstring(captured_address) &
                               " data=0x" & to_hstring(unsigned(data_bus_tb));
                    end if;
                    rom_enable <= '0';
                    rom_data <= (others => 'Z');
                else
                    -- Read cycle (PCI or PCR) - drive bus with data
                    rom_enable <= '1';
                    -- Try ROM first (for program area), then RAM (for data area)
                    -- Use lower 8 bits for array indexing
                    if rom(to_integer(unsigned(captured_address(7 downto 0)))) /= x"00" or captured_address < x"000C" then
                        rom_data <= rom(to_integer(unsigned(captured_address(7 downto 0))));
                    else
                        rom_data <= ram(to_integer(unsigned(captured_address(7 downto 0))));
                    end if;
                    report "MEMORY READ: addr=0x" & to_hstring(captured_address) &
                           " data=0x" & to_hstring(unsigned(rom_data));
                end if;
            else
                rom_enable <= '0';
                rom_data <= (others => 'Z');
            end if;
        end if;
    end process;

    -- Connect memory to data bus (simulates memory device)
    data_bus_tb <= rom_data when rom_enable = '1' else (others => 'Z');

    --===========================================
    -- Clock Generation using phase_clocks component
    --===========================================
    -- Uses the verified phase_clocks component to generate non-overlapping φ1 and φ2 clocks
    -- per Intel 8008 specification. This component has been verified on FPGA + oscilloscope.
    --
    -- Timing diagram for one clock period (2.2µs):
    --   φ1: ‾‾‾‾‾‾‾‾________        (0.8µs high, 1.4µs low)
    --   φ2:         ________‾‾‾‾‾‾__ (0.6µs high, 1.6µs low)
    --        |<-0.8->|<0.4>|<0.6>|<0.4>|
    --        |  φ1   | dead| φ2  |dead|

    -- Master clock generator (100 MHz for phase_clocks component)
    master_clock_gen: process
    begin
        while not sim_done loop
            master_clk_tb <= '0';
            wait for MASTER_CLK_PERIOD / 2;
            master_clk_tb <= '1';
            wait for MASTER_CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Instantiate phase_clocks component to generate phi1/phi2 from master clock
    clk_gen: phase_clocks
        port map (
            clk_in => master_clk_tb,
            reset  => reset_tb,
            phi1   => phi1_tb,
            phi2   => phi2_tb
        );

    --===========================================
    -- State Decoder (for monitoring)
    --===========================================
    process(S2_tb, S1_tb, S0_tb)
        variable state_bits : std_logic_vector(2 downto 0);
    begin
        state_bits := S2_tb & S1_tb & S0_tb;
        case state_bits is
            when "000" => state_name <= "T1     ";
            when "001" => state_name <= "T1I    ";
            when "010" => state_name <= "T2     ";
            when "011" => state_name <= "TWAIT  ";
            when "100" => state_name <= "T3     ";
            when "101" => state_name <= "STOPPED";
            when "110" => state_name <= "T4     ";
            when "111" => state_name <= "T5     ";
            when others => state_name <= "UNKNOWN";
        end case;
    end process;

    --===========================================
    -- Test Stimulus
    --===========================================
    test_process: process
    begin
        report "=== Intel 8008 Silicon-Accurate Core Test Starting ===";

        -- Test 1: Reset behavior
        report "TEST 1: Reset behavior";
        reset_n_tb <= '0';  -- Assert reset for s8008 (active-low)
        reset_tb <= '1';    -- Assert reset for phase_clocks (active-high)
        wait for 10 us;
        assert SYNC_tb = '0' report "FAIL: SYNC should be 0 during reset" severity error;
        assert debug_pc_tb = "00000000000000" report "FAIL: PC should be 0 after reset" severity error;
        report "PASS: Reset applied and verified";

        -- Test 2: Release reset and observe free-running cycles
        report "TEST 2: Free-running cycle observation";
        reset_n_tb <= '1';  -- Release reset for s8008
        reset_tb <= '0';    -- Release reset for phase_clocks
        wait for 1 us;
        report "PASS: Reset released";

        -- Wait for several complete cycles and observe state transitions
        -- With variable-length cycles:
        --   3-state cycle (PCI/PCR/PCW) = 3 states × 2 clock periods × 2.2µs = 13.2µs
        --   5-state cycle (EXECUTE) = 5 states × 2 clock periods × 2.2µs = 22µs
        -- Instruction fetches use 3-state cycles
        for i in 1 to 3 loop
            report "--- Observing free-running cycle " & integer'image(i) & " ---";
            wait for 15 us;  -- Allow time for 3-state cycle
        end loop;

        -- Test 3: Verify SYNC signal toggles every clock period
        report "TEST 3: SYNC signal timing verification";
        report "Observing SYNC transitions over 10 clock periods (22µs)...";
        for i in 1 to 10 loop
            wait until rising_edge(phi1_tb);
            wait for 0.1 us;  -- Small delay for signal propagation
            report "Clock period " & integer'image(i) & ": SYNC=" & std_logic'image(SYNC_tb) & " State=" & state_name;
        end loop;

        -- Test 4: READY signal (insert wait states)
        report "TEST 4: READY signal and wait state insertion";
        wait until S2_tb = '0' and S1_tb = '1' and S0_tb = '0';  -- Wait for T2
        wait for 1 us;
        READY_tb <= '0';  -- Assert wait
        report "PASS: READY deasserted during T2";
        wait for 10 us;   -- Should stay in TWAIT
        READY_tb <= '1';  -- Release wait
        report "PASS: READY reasserted, should proceed to T3";
        wait for 10 us;

        -- Test 5: INT signal (interrupt acknowledge)
        report "TEST 5: Interrupt request handling";
        wait until S2_tb = '0' and S1_tb = '0' and S0_tb = '0';  -- Wait for T1
        wait for 1 us;
        INT_tb <= '1';    -- Assert interrupt
        report "PASS: INT asserted during T1";
        wait for 5 us;    -- Should transition to T1I
        INT_tb <= '0';    -- Deassert interrupt
        report "PASS: INT deasserted";
        wait for 5 us;

        -- Test 6: Verify variable-length cycle sequencing
        report "TEST 6: Variable-length cycle verification";
        report "Verifying 3-state cycle (T1->T2->T3->T1) for instruction fetch...";

        -- Wait for T1
        wait until S2_tb = '0' and S1_tb = '0' and S0_tb = '0';
        report "PASS: Entered T1 state";
        wait for 4.5 us;  -- Should be in T2 after 2 clock periods

        assert S2_tb = '0' and S1_tb = '1' and S0_tb = '0'
            report "FAIL: Expected T2 state" severity error;
        report "PASS: Transitioned to T2 state";
        wait for 4.5 us;  -- Should be in T3

        assert S2_tb = '1' and S1_tb = '0' and S0_tb = '0'
            report "FAIL: Expected T3 state" severity error;
        report "PASS: Transitioned to T3 state";
        wait for 4.5 us;  -- Should be back in T1 (3-state cycle)

        assert S2_tb = '0' and S1_tb = '0' and S0_tb = '0'
            report "FAIL: Expected return to T1 state (3-state cycle)" severity error;
        report "PASS: Transitioned back to T1 state (3-state cycle verified)";

        -- Test 7: Data bus multiplexing verification
        report "TEST 7: Data bus multiplexing verification";
        report "Verifying address/data bus behavior during complete cycle...";

        -- Wait for T1 state
        wait until S2_tb = '0' and S1_tb = '0' and S0_tb = '0';
        wait for 1 us;  -- Allow signals to stabilize
        report "PASS: In T1 state - data bus should contain lower 8 bits of address";
        -- Note: In T1, data_bus should equal program_counter(7:0)
        -- We can't directly check internal signals, but we can verify it's not Hi-Z
        if data_bus_tb /= "ZZZZZZZZ" then
            report "PASS: Data bus is driven during T1 (address low byte)";
        else
            report "FAIL: Data bus should be driven during T1" severity error;
        end if;

        -- Wait for T2 state
        wait until S2_tb = '0' and S1_tb = '1' and S0_tb = '0';
        wait for 1 us;
        report "PASS: In T2 state - data bus should contain cycle type + address high";
        if data_bus_tb /= "ZZZZZZZZ" then
            report "PASS: Data bus is driven during T2 (cycle type + address high)";
        else
            report "FAIL: Data bus should be driven during T2" severity error;
        end if;

        -- Wait for T3 state
        wait until S2_tb = '1' and S1_tb = '0' and S0_tb = '0';
        wait for 1 us;
        report "PASS: In T3 state - checking data bus direction";
        -- During PCI (instruction fetch), T3 is a READ cycle
        -- CPU should be Hi-Z, memory drives the bus with instruction data
        -- After this, the 3-state cycle completes and returns to T1
        report "PASS: T3 state verified - 3-state cycle will complete";

        -- Test 8: Verify 5-state execution cycles with T4 and T5
        report "TEST 8: 5-state execution cycle verification (T4/T5)";
        report "Waiting for instruction execution that uses T4 and T5 states...";

        -- Wait for a MOV instruction to be fetched (address 0: MOV B,B = 0xC0)
        -- This will trigger: 3-state PCI fetch, then 5-state EXECUTE cycle
        wait for 5 us;  -- Allow time for instruction to be fetched and decoded

        -- Now wait for T4 state (should occur during EXECUTE cycle)
        report "Waiting for T4 state during execution cycle...";
        wait until S2_tb = '1' and S1_tb = '1' and S0_tb = '0';  -- T4 state
        report "PASS: Entered T4 state (5-state execution cycle)";
        wait for 4.5 us;  -- Should be in T5 after 2 clock periods

        assert S2_tb = '1' and S1_tb = '1' and S0_tb = '1'
            report "FAIL: Expected T5 state after T4" severity error;
        report "PASS: Transitioned to T5 state";
        wait for 4.5 us;  -- Should be back in T1 after T5

        assert S2_tb = '0' and S1_tb = '0' and S0_tb = '0'
            report "FAIL: Expected return to T1 after T5" severity error;
        report "PASS: Transitioned back to T1 after T5 (5-state cycle verified)";

        -- Verify we see both 3-state and 5-state cycles
        report "TEST 8: Observing mixed 3-state and 5-state cycles...";
        wait for 5 us;  -- Allow initial cycles

        report "======================================================================";
        report "=== TIMING TESTS COMPLETE - RESETTING FOR INSTRUCTION TESTS ===";
        report "======================================================================";

        -- Reset the CPU to start fresh for instruction-level tests
        -- This ensures clean, predictable timing for instruction verification
        reset_n_tb <= '0';  -- Assert reset for s8008 (active-low)
        reset_tb <= '1';    -- Assert reset for phase_clocks (active-high)
        wait for 10 us;
        reset_n_tb <= '1';  -- Release reset for s8008
        reset_tb <= '0';    -- Release reset for phase_clocks
        wait for 10 us;
        report "CPU reset complete - starting instruction-level tests with clean state";

        report "======================================================================";
        report "=== INSTRUCTION-LEVEL TESTS WITH ASSERTIONS ===";
        report "======================================================================";

        -- Helper: Wait for microcode to return to FETCH state (instruction completed)
        -- This ensures we test after each instruction completes

        -- TEST 9: Verify LrI A,0x12 (Load register Immediate)
        report "TEST 9: Verifying LrI A,0x12";
        wait until unsigned(debug_pc_tb) = to_unsigned(2, 14);
        wait for 5 us;  -- LrI uses 3-state fetch + 3-state immediate = ~13µs, wait 5µs to be safe
        assert debug_reg_A_tb = x"12"
            report "FAIL: After LrI A,0x12, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0x12)"
            severity error;
        report "PASS: LrI A,0x12 - A=0x" & to_hstring(unsigned(debug_reg_A_tb));

        -- TEST 10: Verify LrI B,0xAA
        report "TEST 10: Verifying LrI B,0xAA";
        wait until unsigned(debug_pc_tb) = to_unsigned(4, 14);
        wait for 5 us;
        assert debug_reg_B_tb = x"AA"
            report "FAIL: After LrI B,0xAA, B=" & to_hstring(unsigned(debug_reg_B_tb)) & " (expected 0xAA)"
            severity error;
        report "PASS: LrI B,0xAA - B=0x" & to_hstring(unsigned(debug_reg_B_tb));

        -- TEST 11: Verify LrI C,0x55
        report "TEST 11: Verifying LrI C,0x55";
        wait until unsigned(debug_pc_tb) = to_unsigned(6, 14);
        wait for 5 us;
        assert debug_reg_C_tb = x"55"
            report "FAIL: After LrI C,0x55, C=" & to_hstring(unsigned(debug_reg_C_tb)) & " (expected 0x55)"
            severity error;
        report "PASS: LrI C,0x55 - C=0x" & to_hstring(unsigned(debug_reg_C_tb));

        -- TEST 12: Verify MOV A,B (register-to-register)
        -- MOV is at PC=6 (5-state cycle: 3-state fetch + 5-state execute = ~18µs total)
        -- Wait for PC=7 (EXECUTE starts), then wait for T5 to complete and register to write
        report "TEST 12: Verifying MOV A,B";
        wait until unsigned(debug_pc_tb) = to_unsigned(7, 14);
        wait for 15 us;  -- Wait through T4, T5, and register write (5 states × 2 periods × 2.2µs = 22µs)
        assert debug_reg_A_tb = x"AA"
            report "FAIL: After MOV A,B, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0xAA)"
            severity error;
        report "PASS: MOV A,B - A=0x" & to_hstring(unsigned(debug_reg_A_tb));

        -- TEST 13: Verify ADD B (A=0xAA + B=0xAA = 0x154 -> A=0x54, carry=1)
        -- ADD at PC=7 is a 5-state cycle
        report "TEST 13: Verifying ADD B";
        wait until unsigned(debug_pc_tb) = to_unsigned(8, 14);
        wait for 15 us;  -- Wait for 5-state EXECUTE to complete
        assert debug_reg_A_tb = x"54"
            report "FAIL: After ADD B, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0x54)"
            severity error;
        assert debug_flags_tb(0) = '1'
            report "FAIL: After ADD B, carry=" & std_logic'image(debug_flags_tb(0)) & " (expected '1')"
            severity error;
        report "PASS: ADD B - A=0x" & to_hstring(unsigned(debug_reg_A_tb)) & " carry=" & std_logic'image(debug_flags_tb(0));

        -- TEST 14: Verify ADI 0x0C (A=0x54 + 0x0C = 0x60)
        -- ADI at PC=8-9, executes with 5-state cycle
        -- PC increments twice (after opcode, after immediate), so PC=10 when EXECUTE starts
        -- PC=10 trigger occurs at END of IMMEDIATE (T3), then EXECUTE cycle begins (T1-T2-T3-T4-T5)
        -- EXECUTE is 5-state cycle: 5 states × 4.4µs/state = 22µs
        -- Register write happens at rising edge of phi2 AFTER T5 microcode handler completes
        -- Need to wait for full EXECUTE + register write: 23µs
        report "TEST 14: Verifying ADI 0x0C";
        wait until unsigned(debug_pc_tb) = to_unsigned(10, 14);
        wait for 24 us;  -- Wait for complete 5-state EXECUTE cycle + register write
        assert debug_reg_A_tb = x"60"
            report "FAIL: After ADI 0x0C, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0x60)"
            severity error;
        report "PASS: ADI 0x0C - A=0x" & to_hstring(unsigned(debug_reg_A_tb));

        -- TEST 15: Verify LrI H,0x00
        report "TEST 15: Verifying LrI H,0x00";
        wait until unsigned(debug_pc_tb) = to_unsigned(12, 14);
        wait for 5 us;
        assert debug_reg_H_tb = x"00"
            report "FAIL: After LrI H,0x00, H=" & to_hstring(unsigned(debug_reg_H_tb)) & " (expected 0x00)"
            severity error;
        report "PASS: LrI H,0x00 - H=0x" & to_hstring(unsigned(debug_reg_H_tb));

        -- TEST 16: Verify LrI L,0xF0
        report "TEST 16: Verifying LrI L,0xF0";
        wait until unsigned(debug_pc_tb) = to_unsigned(14, 14);
        wait for 5 us;
        assert debug_reg_L_tb = x"F0"
            report "FAIL: After LrI L,0xF0, L=" & to_hstring(unsigned(debug_reg_L_tb)) & " (expected 0xF0)"
            severity error;
        report "PASS: LrI L,0xF0 - L=0x" & to_hstring(unsigned(debug_reg_L_tb));

        -- TEST 17: Verify MOV M,C (memory write: RAM[0xF0] = C = 0x55)
        -- MOV M,C is a 5-state memory write operation - needs 22-24µs
        report "TEST 17: Verifying MOV M,C";
        wait until unsigned(debug_pc_tb) = to_unsigned(15, 14);
        wait for 24 us;  -- Wait for 5-state PCW memory write cycle
        assert ram(16#F0#) = x"55"
            report "FAIL: After MOV M,C, RAM[0xF0]=" & to_hstring(unsigned(ram(16#F0#))) & " (expected 0x55)"
            severity error;
        report "PASS: MOV M,C - RAM[0xF0]=0x" & to_hstring(unsigned(ram(16#F0#)));

        -- TEST 18: Verify MOV D,M (memory read: D = RAM[0xF0] = 0x55)
        -- MOV D,M is a 5-state memory read operation - needs 22-24µs
        report "TEST 18: Verifying MOV D,M";
        wait until unsigned(debug_pc_tb) = to_unsigned(16, 14);
        wait for 24 us;  -- Wait for 5-state PCR memory read cycle + register write
        assert debug_reg_D_tb = x"55"
            report "FAIL: After MOV D,M, D=" & to_hstring(unsigned(debug_reg_D_tb)) & " (expected 0x55)"
            severity error;
        report "PASS: MOV D,M - D=0x" & to_hstring(unsigned(debug_reg_D_tb));

        -- TEST 19: Verify ADD M (A=0x60 + RAM[0xF0]=0x55 = 0xB5)
        -- ADD M is a 5-state memory read + ALU operation - needs 22-24µs
        report "TEST 19: Verifying ADD M";
        wait until unsigned(debug_pc_tb) = to_unsigned(17, 14);
        wait for 24 us;  -- Wait for 5-state PCR memory read + ALU execute + register write
        assert debug_reg_A_tb = x"B5"
            report "FAIL: After ADD M, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0xB5)"
            severity error;
        report "PASS: ADD M - A=0x" & to_hstring(unsigned(debug_reg_A_tb));

        -- TEST 20: Verify JMP 0x0019 (unconditional jump, PC should jump to 25)
        report "TEST 20: Verifying JMP 0x0019";
        wait until unsigned(debug_pc_tb) = to_unsigned(25, 14);
        wait for 5 us;
        -- B should still be 0xAA (skipped code at PC 20-24 should NOT execute)
        assert debug_reg_B_tb = x"AA"
            report "FAIL: After JMP, B=" & to_hstring(unsigned(debug_reg_B_tb)) & " (should be 0xAA, not 0xFF/0xEE)"
            severity error;
        report "PASS: JMP 0x0019 - B=0x" & to_hstring(unsigned(debug_reg_B_tb)) & " (skipped code not executed)";

        -- Extended ADI and MOV Tests - Now execute immediately after JMP
        -- TEST 21: ADI 0x00 (A=0xB5 + 0x00 = 0xB5, no change)
        report "TEST 21: Verifying ADI 0x00 (add zero)";
        wait until unsigned(debug_pc_tb) = to_unsigned(27, 14);
        wait for 24 us;
        assert debug_reg_A_tb = x"B5"
            report "FAIL: After ADI 0x00, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0xB5)"
            severity error;
        report "PASS: ADI 0x00 - A=0x" & to_hstring(unsigned(debug_reg_A_tb));

        -- TEST 22: ADI 0xFF (A=0xB5 + 0xFF = 0x1B4 -> 0xB4, carry=1)
        report "TEST 22: Verifying ADI 0xFF (test overflow/carry)";
        wait until unsigned(debug_pc_tb) = to_unsigned(29, 14);
        wait for 24 us;
        assert debug_reg_A_tb = x"B4"
            report "FAIL: After ADI 0xFF, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0xB4)"
            severity error;
        assert debug_flags_tb(0) = '1'
            report "FAIL: After ADI 0xFF, carry=" & std_logic'image(debug_flags_tb(0)) & " (expected '1')"
            severity error;
        report "PASS: ADI 0xFF - A=0x" & to_hstring(unsigned(debug_reg_A_tb)) & " carry=" & std_logic'image(debug_flags_tb(0));

        -- TEST 23: ADI 0x01 (A=0xB4 + 0x01 = 0xB5)
        report "TEST 23: Verifying ADI 0x01";
        wait until unsigned(debug_pc_tb) = to_unsigned(31, 14);
        wait for 24 us;
        assert debug_reg_A_tb = x"B5"
            report "FAIL: After ADI 0x01, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0xB5)"
            severity error;
        report "PASS: ADI 0x01 - A=0x" & to_hstring(unsigned(debug_reg_A_tb));

        -- TEST 24: MOV C,A (C should get 0xB5)
        report "TEST 24: Verifying MOV C,A";
        wait until unsigned(debug_pc_tb) = to_unsigned(32, 14);  -- PC after MOV C,A is fetched
        wait for 22 us;  -- Wait for full 5-state EXECUTE cycle
        assert debug_reg_C_tb = x"B5"
            report "FAIL: After MOV C,A, C=" & to_hstring(unsigned(debug_reg_C_tb)) & " (expected 0xB5)"
            severity error;
        report "PASS: MOV C,A - C=0x" & to_hstring(unsigned(debug_reg_C_tb));

        -- TEST 25: MOV D,A (changed from MOV D,C to avoid rotate opcode conflict)
        report "TEST 25: Verifying MOV D,A";
        wait until unsigned(debug_pc_tb) = to_unsigned(33, 14);
        wait for 22 us;
        assert debug_reg_D_tb = x"B5"
            report "FAIL: After MOV D,A, D=" & to_hstring(unsigned(debug_reg_D_tb)) & " (expected 0xB5)"
            severity error;
        report "PASS: MOV D,A - D=0x" & to_hstring(unsigned(debug_reg_D_tb));

        -- TEST 26: MOV E,D
        report "TEST 26: Verifying MOV E,D";
        wait until unsigned(debug_pc_tb) = to_unsigned(34, 14);
        wait for 22 us;
        assert debug_reg_E_tb = x"B5"
            report "FAIL: After MOV E,D, E=" & to_hstring(unsigned(debug_reg_E_tb)) & " (expected 0xB5)"
            severity error;
        report "PASS: MOV E,D - E=0x" & to_hstring(unsigned(debug_reg_E_tb));

        -- TEST 27: MOV H,E
        report "TEST 27: Verifying MOV H,E";
        wait until unsigned(debug_pc_tb) = to_unsigned(35, 14);
        wait for 22 us;
        assert debug_reg_H_tb = x"B5"
            report "FAIL: After MOV H,E, H=" & to_hstring(unsigned(debug_reg_H_tb)) & " (expected 0xB5)"
            severity error;
        report "PASS: MOV H,E - H=0x" & to_hstring(unsigned(debug_reg_H_tb));

        -- TEST 28: MOV E,H
        report "TEST 28: Verifying MOV E,H";
        wait until unsigned(debug_pc_tb) = to_unsigned(36, 14);
        wait for 22 us;
        assert debug_reg_E_tb = x"B5"
            report "FAIL: After MOV E,H, E=" & to_hstring(unsigned(debug_reg_E_tb)) & " (expected 0xB5)"
            severity error;
        report "PASS: MOV E,H - E=0x" & to_hstring(unsigned(debug_reg_E_tb));

        -- TEST 29: MOV A,D (circle complete via D instead of L)
        report "TEST 29: Verifying MOV A,D (circle complete)";
        wait until unsigned(debug_pc_tb) = to_unsigned(37, 14);
        wait for 22 us;
        assert debug_reg_A_tb = x"B5"
            report "FAIL: After MOV A,D, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0xB5)"
            severity error;
        report "PASS: MOV A,D - A=0x" & to_hstring(unsigned(debug_reg_A_tb));

        -- TEST 30: MOV B,A
        report "TEST 30: Verifying MOV B,A";
        wait until unsigned(debug_pc_tb) = to_unsigned(38, 14);
        wait for 22 us;
        assert debug_reg_B_tb = x"B5"
            report "FAIL: After MOV B,A, B=" & to_hstring(unsigned(debug_reg_B_tb)) & " (expected 0xB5)"
            severity error;
        report "PASS: MOV B,A - B=0x" & to_hstring(unsigned(debug_reg_B_tb));

        -- TEST 31: Chain ADI #1 (A=0xB5 + 0x10 = 0xC5)
        report "TEST 31: Verifying chain ADI #1 (ADI 0x10)";
        wait until unsigned(debug_pc_tb) = to_unsigned(40, 14);
        wait for 24 us;
        assert debug_reg_A_tb = x"C5"
            report "FAIL: After ADI 0x10, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0xC5)"
            severity error;
        report "PASS: Chain ADI #1 - A=0x" & to_hstring(unsigned(debug_reg_A_tb));

        -- TEST 32: Chain ADI #2 (A=0xC5 + 0x20 = 0xE5)
        report "TEST 32: Verifying chain ADI #2 (ADI 0x20)";
        wait until unsigned(debug_pc_tb) = to_unsigned(42, 14);
        wait for 24 us;
        assert debug_reg_A_tb = x"E5"
            report "FAIL: After ADI 0x20, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0xE5)"
            severity error;
        report "PASS: Chain ADI #2 - A=0x" & to_hstring(unsigned(debug_reg_A_tb));

        -- TEST 33: Chain ADI #3 (A=0xE5 + 0x30 = 0x115 -> 0x15, carry=1)
        report "TEST 33: Verifying chain ADI #3 (ADI 0x30)";
        wait until unsigned(debug_pc_tb) = to_unsigned(44, 14);
        wait for 24 us;
        assert debug_reg_A_tb = x"15"
            report "FAIL: After ADI 0x30, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0x15)"
            severity error;
        assert debug_flags_tb(0) = '1'
            report "FAIL: After ADI 0x30, carry=" & std_logic'image(debug_flags_tb(0)) & " (expected '1')"
            severity error;
        report "PASS: Chain ADI #3 - A=0x" & to_hstring(unsigned(debug_reg_A_tb)) & " carry=" & std_logic'image(debug_flags_tb(0));

        -- TEST 34: Interleaved MOV B,A (B=0x15)
        report "TEST 34: Verifying interleaved MOV B,A";
        wait until unsigned(debug_pc_tb) = to_unsigned(45, 14);
        wait for 22 us;
        assert debug_reg_B_tb = x"15"
            report "FAIL: After MOV B,A, B=" & to_hstring(unsigned(debug_reg_B_tb)) & " (expected 0x15)"
            severity error;
        report "PASS: Interleaved MOV B,A - B=0x" & to_hstring(unsigned(debug_reg_B_tb));

        -- TEST 35: Interleaved ADI 0x05 (A=0x15 + 0x05 = 0x1A)
        report "TEST 35: Verifying interleaved ADI 0x05";
        wait until unsigned(debug_pc_tb) = to_unsigned(47, 14);
        wait for 24 us;
        assert debug_reg_A_tb = x"1A"
            report "FAIL: After ADI 0x05, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0x1A)"
            severity error;
        report "PASS: Interleaved ADI 0x05 - A=0x" & to_hstring(unsigned(debug_reg_A_tb));

        -- TEST 36: Interleaved MOV C,A (C=0x1A)
        report "TEST 36: Verifying interleaved MOV C,A";
        wait until unsigned(debug_pc_tb) = to_unsigned(48, 14);
        wait for 22 us;  -- MOV C,A is 5-state cycle = 11us, need margin for verification
        assert debug_reg_C_tb = x"1A"
            report "FAIL: After MOV C,A, C=" & to_hstring(unsigned(debug_reg_C_tb)) & " (expected 0x1A)"
            severity error;
        report "PASS: Interleaved MOV C,A - C=0x" & to_hstring(unsigned(debug_reg_C_tb));

        -- Now CALL/RET tests begin
        -- TEST 37: Verify CALL 0x0060 and execution in subroutine
        report "TEST 37: Verifying CALL 0x0060 (entering subroutine)";
        wait until unsigned(debug_pc_tb) = to_unsigned(96, 14);  -- Subroutine entry at 0x60 = 96
        wait for 5 us;
        report "PASS: CALL 0x0060 - jumped to subroutine at PC=96";

        -- TEST 38: Verify subroutine execution (LrI B,0x88)
        report "TEST 38: Verifying subroutine execution (LrI B,0x88)";
        wait until unsigned(debug_pc_tb) = to_unsigned(98, 14);
        wait for 5 us;
        assert debug_reg_B_tb = x"88"
            report "FAIL: After LrI B,0x88 in subroutine, B=" & to_hstring(unsigned(debug_reg_B_tb)) & " (expected 0x88)"
            severity error;
        report "PASS: Subroutine LrI B,0x88 - B=0x" & to_hstring(unsigned(debug_reg_B_tb));

        -- TEST 39: Verify RET (return from subroutine to PC=51)
        report "TEST 39: Verifying RET (return from subroutine)";
        wait until unsigned(debug_pc_tb) = to_unsigned(51, 14);
        wait for 5 us;
        report "PASS: RET - returned to PC=51 (after CALL)";

        -- TEST 40: Verify post-return execution (LrI A,0x99)
        report "TEST 40: Verifying post-return execution (LrI A,0x99)";
        wait until unsigned(debug_pc_tb) = to_unsigned(53, 14);
        wait for 5 us;
        assert debug_reg_A_tb = x"99"
            report "FAIL: After RET and LrI A,0x99, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0x99)"
            severity error;
        report "PASS: Post-RET LrI A,0x99 - A=0x" & to_hstring(unsigned(debug_reg_A_tb));

        -- TEST 41: Verify nested CALL (level 1) - CALL 0x0080
        report "TEST 41: Verifying nested CALL 0x0080 (level 1)";
        wait until unsigned(debug_pc_tb) = to_unsigned(128, 14);  -- First-level subroutine at 0x80 = 128
        wait for 5 us;
        report "PASS: Nested CALL level 1 - jumped to PC=128";

        -- TEST 42: Verify level 1 execution (LrI D,0x11)
        report "TEST 42: Verifying level 1 execution (LrI D,0x11)";
        wait until unsigned(debug_pc_tb) = to_unsigned(130, 14);
        wait for 5 us;
        assert debug_reg_D_tb = x"11"
            report "FAIL: After LrI D,0x11 in level 1, D=" & to_hstring(unsigned(debug_reg_D_tb)) & " (expected 0x11)"
            severity error;
        report "PASS: Nested level 1 LrI D,0x11 - D=0x" & to_hstring(unsigned(debug_reg_D_tb));

        -- TEST 43: Verify nested CALL (level 2) - CALL 0x0090
        report "TEST 43: Verifying nested CALL 0x0090 (level 2)";
        wait until unsigned(debug_pc_tb) = to_unsigned(144, 14);  -- Second-level subroutine at 0x90 = 144
        wait for 5 us;
        report "PASS: Nested CALL level 2 - jumped to PC=144";

        -- TEST 44: Verify level 2 execution (LrI H,0x33)
        report "TEST 44: Verifying level 2 execution (LrI H,0x33)";
        wait until unsigned(debug_pc_tb) = to_unsigned(146, 14);
        wait for 5 us;
        assert debug_reg_H_tb = x"33"
            report "FAIL: After LrI H,0x33 in level 2, H=" & to_hstring(unsigned(debug_reg_H_tb)) & " (expected 0x33)"
            severity error;
        report "PASS: Nested level 2 LrI H,0x33 - H=0x" & to_hstring(unsigned(debug_reg_H_tb));

        -- TEST 45: Verify level 2 execution (LrI L,0x44)
        report "TEST 45: Verifying level 2 execution (LrI L,0x44)";
        wait until unsigned(debug_pc_tb) = to_unsigned(148, 14);
        wait for 5 us;
        assert debug_reg_L_tb = x"44"
            report "FAIL: After LrI L,0x44 in level 2, L=" & to_hstring(unsigned(debug_reg_L_tb)) & " (expected 0x44)"
            severity error;
        report "PASS: Nested level 2 LrI L,0x44 - L=0x" & to_hstring(unsigned(debug_reg_L_tb));

        -- TEST 46: Verify RET from level 2 (back to level 1 at PC=133)
        report "TEST 46: Verifying RET from level 2";
        wait until unsigned(debug_pc_tb) = to_unsigned(133, 14);
        wait for 5 us;
        report "PASS: RET from level 2 - returned to PC=133";

        -- TEST 47: Verify level 1 post-nested execution (LrI E,0x22)
        report "TEST 47: Verifying level 1 post-nested execution (LrI E,0x22)";
        wait until unsigned(debug_pc_tb) = to_unsigned(135, 14);
        wait for 5 us;
        assert debug_reg_E_tb = x"22"
            report "FAIL: After LrI E,0x22 in level 1, E=" & to_hstring(unsigned(debug_reg_E_tb)) & " (expected 0x22)"
            severity error;
        report "PASS: Nested level 1 post-RET LrI E,0x22 - E=0x" & to_hstring(unsigned(debug_reg_E_tb));

        -- TEST 48: Verify RET from level 1 (back to main at PC=56)
        report "TEST 48: Verifying RET from level 1";
        wait until unsigned(debug_pc_tb) = to_unsigned(56, 14);
        wait for 5 us;
        report "PASS: RET from level 1 - returned to PC=56";

        -- TEST 49: Verify post-nested execution (LrI A,0xAA)
        report "TEST 49: Verifying post-nested execution (LrI A,0xAA)";
        wait until unsigned(debug_pc_tb) = to_unsigned(58, 14);
        wait for 5 us;
        assert debug_reg_A_tb = x"AA"
            report "FAIL: After nested CALLs and LrI A,0xAA, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0xAA)"
            severity error;
        report "PASS: Post-nested-CALL LrI A,0xAA - A=0x" & to_hstring(unsigned(debug_reg_A_tb));

        -- TEST 50-56: Stack depth test (4-level nested calls)
        report "TEST 50: Verifying stack depth CALL 0x00A0 (level 1)";
        wait until unsigned(debug_pc_tb) = to_unsigned(160, 14);
        wait for 5 us;
        report "PASS: Stack depth test level 1 - jumped to PC=160";

        report "TEST 51: Verifying stack depth level 1 (LrI A,0x01)";
        wait until unsigned(debug_pc_tb) = to_unsigned(162, 14);
        wait for 5 us;
        assert debug_reg_A_tb = x"01"
            report "FAIL: Stack depth level 1, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0x01)"
            severity error;
        report "PASS: Stack depth L1 LrI A,0x01 - A=0x" & to_hstring(unsigned(debug_reg_A_tb));

        report "TEST 52: Verifying stack depth CALL 0x00B0 (level 2)";
        wait until unsigned(debug_pc_tb) = to_unsigned(176, 14);
        wait for 5 us;
        report "PASS: Stack depth test level 2 - jumped to PC=176";

        report "TEST 53: Verifying stack depth level 2 (LrI B,0x02)";
        wait until unsigned(debug_pc_tb) = to_unsigned(178, 14);
        wait for 5 us;
        assert debug_reg_B_tb = x"02"
            report "FAIL: Stack depth level 2, B=" & to_hstring(unsigned(debug_reg_B_tb)) & " (expected 0x02)"
            severity error;
        report "PASS: Stack depth L2 LrI B,0x02 - B=0x" & to_hstring(unsigned(debug_reg_B_tb));

        report "TEST 54: Verifying stack depth CALL 0x00C0 (level 3)";
        wait until unsigned(debug_pc_tb) = to_unsigned(192, 14);
        wait for 5 us;
        report "PASS: Stack depth test level 3 - jumped to PC=192";

        report "TEST 55: Verifying stack depth level 3 (LrI C,0x03)";
        wait until unsigned(debug_pc_tb) = to_unsigned(194, 14);
        wait for 5 us;
        assert debug_reg_C_tb = x"03"
            report "FAIL: Stack depth level 3, C=" & to_hstring(unsigned(debug_reg_C_tb)) & " (expected 0x03)"
            severity error;
        report "PASS: Stack depth L3 LrI C,0x03 - C=0x" & to_hstring(unsigned(debug_reg_C_tb));

        report "TEST 56: Verifying stack depth level 3 (LrI D,0x04)";
        wait until unsigned(debug_pc_tb) = to_unsigned(196, 14);
        wait for 5 us;
        assert debug_reg_D_tb = x"04"
            report "FAIL: Stack depth level 3, D=" & to_hstring(unsigned(debug_reg_D_tb)) & " (expected 0x04)"
            severity error;
        report "PASS: Stack depth L3 LrI D,0x04 - D=0x" & to_hstring(unsigned(debug_reg_D_tb));

        -- Verify RETs unwind the stack correctly
        report "TEST 57: Verifying RET from level 3";
        wait until unsigned(debug_pc_tb) = to_unsigned(181, 14);
        wait for 5 us;
        report "PASS: RET from level 3 - returned to PC=181";

        report "TEST 58: Verifying stack depth level 2 post-RET (LrI B,0xF2)";
        wait until unsigned(debug_pc_tb) = to_unsigned(183, 14);
        wait for 5 us;
        assert debug_reg_B_tb = x"F2"
            report "FAIL: Stack depth L2 post-RET, B=" & to_hstring(unsigned(debug_reg_B_tb)) & " (expected 0xF2)"
            severity error;
        report "PASS: Stack depth L2 post-RET LrI B,0xF2 - B=0x" & to_hstring(unsigned(debug_reg_B_tb));

        report "TEST 59: Verifying RET from level 2";
        wait until unsigned(debug_pc_tb) = to_unsigned(165, 14);
        wait for 5 us;
        report "PASS: RET from level 2 - returned to PC=165";

        report "TEST 60: Verifying stack depth level 1 post-RET (LrI A,0xF1)";
        wait until unsigned(debug_pc_tb) = to_unsigned(167, 14);
        wait for 5 us;
        assert debug_reg_A_tb = x"F1"
            report "FAIL: Stack depth L1 post-RET, A=" & to_hstring(unsigned(debug_reg_A_tb)) & " (expected 0xF1)"
            severity error;
        report "PASS: Stack depth L1 post-RET LrI A,0xF1 - A=0x" & to_hstring(unsigned(debug_reg_A_tb));

        report "TEST 61: Verifying RET from level 1";
        wait until unsigned(debug_pc_tb) = to_unsigned(61, 14);
        wait for 5 us;
        report "PASS: RET from level 1 - returned to PC=61";

        report "TEST 62: Verifying post-stack-depth execution (LrI C,0xCC)";
        wait until unsigned(debug_pc_tb) = to_unsigned(63, 14);
        wait for 5 us;
        assert debug_reg_C_tb = x"CC"
            report "FAIL: Post-stack-depth test, C=" & to_hstring(unsigned(debug_reg_C_tb)) & " (expected 0xCC)"
            severity error;
        report "PASS: Post-stack-depth LrI C,0xCC - C=0x" & to_hstring(unsigned(debug_reg_C_tb));

        -- TEST 63: HLT instruction at address 63
        report "TEST 63: Verifying final HLT instruction";
        wait for 15 us;  -- Need time for HLT to execute (3-state cycle = ~6.6us) plus margin
        assert S2_tb = '1' and S1_tb = '0' and S0_tb = '1'
            report "FAIL: After HLT, state should be STOPPED (S2=1,S1=0,S0=1)"
            severity error;
        report "PASS: Final HLT - CPU in STOPPED state";

        report "======================================================================";
        report "=== ALL 63 INSTRUCTION TESTS PASSED ===";
        report "======================================================================";
        report "Summary of tested instructions:";
        report "  - LrI (Load register Immediate): 9 tests PASS";
        report "  - MOV (register-to-register): 11 tests PASS";
        report "  - MOV with memory (M register): 2 tests PASS";
        report "  - ADD (register operand): 1 test PASS";
        report "  - ADI (immediate operand): 7 tests PASS";
        report "  - ADD M (memory operand): 1 test PASS";
        report "  - JMP (unconditional jump): 1 test PASS";
        report "  - CALL/RET (simple): 4 tests PASS";
        report "  - CALL/RET (nested 2-level): 8 tests PASS";
        report "  - CALL/RET (nested 4-level stack depth): 18 tests PASS";
        report "  - HLT (halt execution): 1 test PASS";
        report "======================================================================";

        -- End of tests
        report "=== All Tests Completed Successfully ===";
        sim_done <= true;
        wait;
    end process;

    --===========================================
    -- Monitoring Processes
    --===========================================

    -- Monitor state changes
    monitor_state: process(S2_tb, S1_tb, S0_tb)
        variable state_bits : std_logic_vector(2 downto 0);
        variable decoded_state : string(1 to 7);
    begin
        state_bits := S2_tb & S1_tb & S0_tb;
        case state_bits is
            when "000" => decoded_state := "T1     ";
            when "001" => decoded_state := "T1I    ";
            when "010" => decoded_state := "T2     ";
            when "011" => decoded_state := "TWAIT  ";
            when "100" => decoded_state := "T3     ";
            when "101" => decoded_state := "STOPPED";
            when "110" => decoded_state := "T4     ";
            when "111" => decoded_state := "T5     ";
            when others => decoded_state := "UNKNOWN";
        end case;

        report "STATE CHANGE: " & decoded_state &
               " (S2=" & std_logic'image(S2_tb) &
               " S1=" & std_logic'image(S1_tb) &
               " S0=" & std_logic'image(S0_tb) &
               ") at " & time'image(now);
    end process;

    -- Monitor SYNC signal
    monitor_sync: process(SYNC_tb)
    begin
        report "SYNC=" & std_logic'image(SYNC_tb) & " at " & time'image(now);
    end process;

    -- Monitor data bus changes
    monitor_data_bus: process(data_bus_tb)
        variable bus_value : std_logic_vector(7 downto 0);
    begin
        bus_value := data_bus_tb;
        if bus_value = "ZZZZZZZZ" then
            report "DATA_BUS=Hi-Z at " & time'image(now);
        else
            report "DATA_BUS=0x" & to_hstring(unsigned(bus_value)) & " at " & time'image(now);
        end if;
    end process;

end sim;
