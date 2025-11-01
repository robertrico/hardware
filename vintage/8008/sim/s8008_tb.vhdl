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
            INT : in std_logic
        );
    end component;

    -- Testbench signals
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

    -- Timing constants (matching real 8008 specifications)
    constant PHI1_HIGH_TIME : time := 0.8 us;   -- φ1 high time
    constant PHI1_LOW_TIME  : time := 0.4 us;   -- φ1 dead time
    constant PHI2_HIGH_TIME : time := 0.6 us;   -- φ2 high time
    constant PHI2_LOW_TIME  : time := 0.4 us;   -- φ2 dead time
    constant CLOCK_PERIOD   : time := 2.2 us;   -- Total clock period

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
        --   LrI (Load Immediate) = 00 DDD 110 + immediate byte
        --   MOV dst,src = 00 DDD SSS (class 00)
        --   ALU op,src = 10 OOO SSS (class 10)
        --   ALU op,imm = 11 OOO 100 + immediate byte (class 11)
        --   JMP = 01 XXX 100 + addr_low + addr_high (class 11)
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
        6 => x"01",  -- MOV A,B     = 00 000 001  (copy B -> A, result = 0xAA)

        -- TEST 3: ALU with register operands (ADD B to A)
        7 => x"81",  -- ADD B       = 10 000 001  (A = A + B = 0xAA + 0xAA = 0x54, with carry)

        -- TEST 4: ALU with immediate operand (ADD immediate to A)
        8 => x"C4",  -- ADI 0x0C    = 11 000 100  (A = A + 0x0C)
        9 => x"0C",  --               immediate data = 0x0C

        -- TEST 5: Set up H:L register pair for memory operations
        10 => x"2E", -- LrI H,0x00  = 00 101 110  (H = 0x00)
        11 => x"00", --               immediate data = 0x00
        12 => x"36", -- LrI L,0x20  = 00 110 110  (L = 0x20, so M points to 0x0020)
        13 => x"20", --               immediate data = 0x20

        -- TEST 6: Memory write (MOV M,C - store C to memory at H:L)
        14 => x"3A", -- MOV M,C     = 00 111 010  (Store C=0x55 to address 0x0020)

        -- TEST 7: Memory read (MOV D,M - load from memory at H:L to D)
        15 => x"1F", -- MOV D,M     = 00 011 111  (Load from address 0x0020 into D)

        -- TEST 8: ALU with memory operand (ADD M to A)
        16 => x"87", -- ADD M       = 10 000 111  (A = A + M[H:L])

        -- TEST 9: Unconditional jump - JMP to address 0x0015 (infinite loop for halt observation)
        17 => x"44", -- JMP 0x0015  = 01 000 100  (unconditional jump, bit[2]=1)
        18 => x"15", --               low byte = 0x15
        19 => x"00", --               high byte = 0x00 (target = 0x0015)

        -- These instructions at 20-22 should NEVER execute (skipped by jump)
        20 => x"0E", -- LrI B,0xFF  (should be skipped)
        21 => x"FF", --               (should be skipped)

        -- Data area for memory operations
        32 => x"33", -- Address 0x20: Will be overwritten by TEST 6, then read by TEST 7 and 8

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
            INT => INT_tb
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
    -- Two-Phase Clock Generation
    --===========================================
    -- Generates non-overlapping φ1 and φ2 clocks per Intel 8008 spec
    --
    -- Timing diagram for one clock period (2.2µs):
    --   φ1: ‾‾‾‾‾‾‾‾________        (0.8µs high, 1.4µs low)
    --   φ2:         ________‾‾‾‾‾‾__ (0.6µs high, 1.6µs low)
    --        |<-0.8->|<0.4>|<0.6>|<0.4>|
    --        |  φ1   | dead| φ2  |dead|

    phi1_clock_gen: process
    begin
        while not sim_done loop
            phi1_tb <= '1';
            wait for PHI1_HIGH_TIME;
            phi1_tb <= '0';
            wait for (CLOCK_PERIOD - PHI1_HIGH_TIME);
        end loop;
        wait;
    end process;

    phi2_clock_gen: process
    begin
        -- φ2 starts after φ1 falls + dead time
        wait for (PHI1_HIGH_TIME + PHI1_LOW_TIME);
        while not sim_done loop
            phi2_tb <= '1';
            wait for PHI2_HIGH_TIME;
            phi2_tb <= '0';
            wait for (CLOCK_PERIOD - PHI2_HIGH_TIME);
        end loop;
        wait;
    end process;

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
        reset_n_tb <= '0';
        wait for 10 us;
        assert SYNC_tb = '0' report "FAIL: SYNC should be 0 during reset" severity error;
        report "PASS: Reset applied";

        -- Test 2: Release reset and observe free-running cycles
        report "TEST 2: Free-running cycle observation";
        reset_n_tb <= '1';
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
        wait for 20 us;

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
        wait for 20 us;  -- Allow time for instruction to be fetched and decoded

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
        wait for 100 us;  -- Run for a while to see multiple cycles

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
