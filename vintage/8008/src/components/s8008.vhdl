-------------------------------------------------------------------------------
-- Intel 8008 Silicon-Accurate Implementation
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Robert Rico
--
-- Cycle-accurate VHDL model of the Intel 8008 microprocessor.
-- This implementation models the actual hardware behavior, not just the ISA.
--
-- Pin-out matches the real Intel 8008 (18-pin DIP package):
--   - 8-bit multiplexed address/data bus (D0-D7)
--   - Two-phase non-overlapping clocks (φ1, φ2)
--   - State outputs (S0, S1, S2)
--   - SYNC output (timing reference)
--   - Control inputs (READY, INT)
--
-- Reference: Intel 8008 Datasheet (April 1974)
-- License: MIT (see LICENSE.txt)
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity s8008 is
    port (
        -- Two-phase clock inputs (non-overlapping)
        -- φ1: high for 0.8µs, then 0.4µs dead time
        -- φ2: high for 0.6µs, then 0.4µs dead time
        -- Total clock period: 2.2µs (φ1 rise to next φ1 rise)
        phi1 : in std_logic;
        phi2 : in std_logic;

        -- Reset (active low)
        reset_n : in std_logic;

        -- 8-bit multiplexed address/data bus (bidirectional)
        -- During T1: D7-D0 = A7-A0 (lower 8 bits of address)
        -- During T2: D7-D6 = cycle type, D5-D0 = A13-A8 (upper 6 bits of address)
        -- During T3: D7-D0 = data (read or write)
        data_bus : inout std_logic_vector(7 downto 0);

        -- State outputs (timing state indication)
        -- S2 S1 S0 = State encoding:
        --   000 = T1    (address low byte)
        --   001 = T1I   (interrupt acknowledge)
        --   010 = T2    (address high byte + cycle type)
        --   011 = WAIT  (wait state)
        --   100 = T3    (data transfer)
        --   101 = STOPPED (halted)
        --   110 = T4    (data hold)
        --   111 = T5    (cycle complete)
        S0 : out std_logic;
        S1 : out std_logic;
        S2 : out std_logic;

        -- SYNC output (timing reference)
        -- Per Intel datasheet: "divide by two of φ2"
        -- SYNC toggles every clock period to distinguish between
        -- the two clock periods within each state (T1-T5)
        SYNC : out std_logic;

        -- READY input (wait state control)
        -- When READY=0 during T2, CPU inserts wait states (TWAIT)
        -- When READY=1, CPU proceeds normally
        READY : in std_logic;

        -- Interrupt request input
        -- When INT=1 during T1, CPU performs interrupt acknowledge (T1I)
        INT : in std_logic;

        -- I/O ports
        -- INP instruction: reads from port_in(MMM) where MMM is 3-bit address (8 ports)
        -- OUT instruction: writes to port_out(RRMMM) where RRMMM is 5-bit address (32 ports)
        port_in : in std_logic_vector(7 downto 0);  -- Input from port 0-7 (selected by port address)
        port_out : out std_logic_vector(7 downto 0); -- Output data
        port_out_addr : out std_logic_vector(4 downto 0); -- Output port address (0-31)
        port_out_strobe : out std_logic; -- Pulse high during OUT instruction execution

        -- Debug outputs (for testbench verification)
        -- These expose internal state for testing purposes
        debug_reg_A : out std_logic_vector(7 downto 0);
        debug_reg_B : out std_logic_vector(7 downto 0);
        debug_reg_C : out std_logic_vector(7 downto 0);
        debug_reg_D : out std_logic_vector(7 downto 0);
        debug_reg_E : out std_logic_vector(7 downto 0);
        debug_reg_H : out std_logic_vector(7 downto 0);
        debug_reg_L : out std_logic_vector(7 downto 0);
        debug_pc : out std_logic_vector(13 downto 0);
        debug_flags : out std_logic_vector(3 downto 0)  -- {parity, sign, zero, carry}
    );
end s8008;

architecture rtl of s8008 is

    --===========================================
    -- Component Declarations
    --===========================================

    -- ALU Component
    component i8008_alu is
        port(
            data_0 : in std_logic_vector(7 downto 0);
            data_1 : in std_logic_vector(7 downto 0);
            flag_carry : in std_logic;
            command : in std_logic_vector(2 downto 0);
            alu_result : out std_logic_vector(8 downto 0)
        );
    end component;

    --===========================================
    -- Debug Configuration
    --===========================================
    -- Set to false to reduce simulation noise (hides clock toggle messages)
    constant DEBUG_VERBOSE : boolean := false;

    --===========================================
    -- Internal Signals
    --===========================================

    -- Clock phase counter for two-clock-period states
    -- Per Intel 8008 datasheet: "Two clock periods are required for each state"
    -- One clock period = φ1 rise → φ1 fall → dead → φ2 rise → φ2 fall → dead → φ1 rise (2.2µs)
    -- Therefore each state (T1, T2, T3, T4, T5) spans TWO φ1 rising edges (4.4µs)
    -- Initialize to '1' so that SYNC (not clock_phase) starts at '0' during reset
    signal clock_phase : std_logic := '1';  -- Toggles every φ1 edge

    -- Timing states (real 8008 hardware states)
    type timing_state_t is (T1, T1I, T2, TWAIT, T3, T4, T5, STOPPED);
    signal timing_state : timing_state_t := T1;

    -- Internal registers for address and data
    -- In a real 8008, these would come from the instruction decoder and register file
    -- For free-running test purposes, we'll use simple counters
    signal program_counter : unsigned(13 downto 0) := (others => '0');  -- 14-bit PC
    signal data_out : std_logic_vector(7 downto 0) := (others => '0');  -- Data to write
    signal cycle_type_reg : std_logic_vector(1 downto 0) := "00";  -- PCI (instruction fetch)
    signal pc_should_increment : std_logic := '1';  -- Whether PC should increment after this cycle
    signal pc_increment_extra : std_logic := '0';  -- Extra increment for skipping unused bytes

    -- Data input and instruction registers
    signal data_in : std_logic_vector(7 downto 0);  -- Data read from bus
    signal instruction_reg : std_logic_vector(7 downto 0);  -- Captured opcode
    signal immediate_data : std_logic_vector(7 downto 0);  -- Captured immediate byte for ALU/LrI instructions

    -- Register File (Intel 8008 has 7 8-bit registers)
    -- Per Intel 8008 datasheet, registers are addressed as:
    --   000 = A (Accumulator)
    --   001 = B
    --   010 = C
    --   011 = D
    --   100 = E
    --   101 = H (High byte of memory pointer)
    --   110 = L (Low byte of memory pointer)
    --   111 = M (Memory reference via H:L - not a physical register)
    type register_file_t is array (0 to 6) of std_logic_vector(7 downto 0);
    signal registers : register_file_t := (others => (others => '0'));

    -- Register addressing aliases for clarity
    constant REG_A : integer := 0;  -- Accumulator
    constant REG_B : integer := 1;
    constant REG_C : integer := 2;
    constant REG_D : integer := 3;
    constant REG_E : integer := 4;
    constant REG_H : integer := 5;  -- High byte of address
    constant REG_L : integer := 6;  -- Low byte of address

    -- Address Stack (8-level LIFO for CALL/RET)
    -- Per Intel 8008 datasheet: 8 levels deep, each 14 bits wide
    -- Stack pointer wraps around (no overflow detection in hardware)
    type address_stack_t is array (0 to 7) of unsigned(13 downto 0);
    signal address_stack : address_stack_t := (others => (others => '0'));
    signal stack_pointer : unsigned(2 downto 0) := (others => '0');  -- 3-bit SP (0-7)

    -- Flags Register (Condition Code bits)
    -- Per Intel 8008 datasheet:
    --   Bit 0: Carry (C)
    --   Bit 1: Zero (Z)
    --   Bit 2: Sign (S)
    --   Bit 3: Parity (P)
    signal flag_carry : std_logic := '0';
    signal flag_zero : std_logic := '0';
    signal flag_sign : std_logic := '0';
    signal flag_parity : std_logic := '0';

    -- Data bus direction control
    signal data_bus_output : std_logic_vector(7 downto 0);
    signal data_bus_enable : std_logic;
    signal is_read_cycle : std_logic;  -- '1' for read (PCI, PCR), '0' for write (PCW)

    -- ALU signals
    signal alu_data_0 : std_logic_vector(7 downto 0);  -- First operand (usually accumulator)
    signal alu_data_1 : std_logic_vector(7 downto 0);  -- Second operand
    signal alu_command : std_logic_vector(2 downto 0);  -- ALU operation select
    signal alu_result : std_logic_vector(8 downto 0);  -- 9-bit result (bit 8 = carry)

    -- Instruction Decoder Signals (PLA outputs)
    -- These are the control signals generated by decoding the opcode
    signal is_alu_op : std_logic;  -- ALU operation (ADD, SUB, AND, OR, XOR, CMP)
    signal is_load_op : std_logic;  -- Register load operation (MOV, MVI)
    signal is_jump_op : std_logic;  -- Jump operation (JMP, JC, JZ, etc.)
    signal is_call_op : std_logic;  -- CALL operation (push PC, jump)
    signal is_ret_op : std_logic;   -- RET operation (pop PC)
    signal is_halt_op : std_logic;  -- HLT operation (stop execution)
    signal src_reg : std_logic_vector(2 downto 0);  -- Source register address
    signal dst_reg : std_logic_vector(2 downto 0);  -- Destination register address
    signal is_immediate : std_logic;  -- Immediate data follows opcode

    -- Rotate operation signals
    signal is_rotate_op : std_logic;  -- Rotate operation (RLC, RRC, RAL, RAR)
    signal rotate_type : std_logic_vector(2 downto 0) := "000";  -- 000=RLC, 001=RRC, 010=RAL, 011=RAR
    signal rotate_result : std_logic_vector(7 downto 0);  -- Result of rotation
    signal rotate_carry : std_logic := '0';  -- New carry flag value from rotation
    signal rotate_saved_carry : std_logic := '0';  -- Captured carry flag at decode time (breaks combinational loop)

    -- Memory reference signals (M register = "111")
    signal src_is_memory : std_logic;  -- Source is M (memory via H:L)
    signal dst_is_memory : std_logic;  -- Destination is M (memory via H:L)
    signal memory_address : unsigned(13 downto 0);  -- Address formed from H:L pair

    -- Microcode Sequencer State
    -- Tracks where we are in multi-cycle instruction execution
    type microcode_state_t is (
        FETCH,       -- Fetching instruction
        EXECUTE,     -- Executing instruction (single-cycle ops)
        IMMEDIATE,   -- Fetching immediate data byte
        MEM_READ,    -- Reading from memory (M register source)
        MEM_WRITE,   -- Writing to memory (M register destination)
        ADDR_LOW,    -- Fetching low byte of address (for jumps)
        ADDR_HIGH    -- Fetching high byte of address (for jumps)
    );
    signal microcode_state : microcode_state_t := FETCH;

    -- Register file access signals
    signal reg_write_enable : std_logic;
    signal reg_read_addr : integer range 0 to 6;
    signal reg_write_addr : integer range 0 to 6;
    signal reg_write_data : std_logic_vector(7 downto 0);
    signal reg_read_data : std_logic_vector(7 downto 0);

    -- Jump/Call/Return address storage
    signal jump_addr_low : std_logic_vector(7 downto 0);   -- Low byte of jump/call address
    signal jump_addr_high : std_logic_vector(5 downto 0);  -- High 6 bits (14-bit address total)
    signal jump_condition : std_logic_vector(1 downto 0);  -- Condition code (00=carry, 01=zero, 10=sign, 11=parity)
    signal jump_condition_sense : std_logic;                -- '0'=JFc (false), '1'=JTc (true)
    signal jump_unconditional : std_logic;                  -- '1' for JMP (unconditional), '0' for conditional
    signal perform_jump : std_logic := '0';                 -- '1' when jump condition is met

    -- Conditional CALL signals
    signal call_condition : std_logic_vector(1 downto 0);  -- Condition code for CALL (00=carry, 01=zero, 10=sign, 11=parity)
    signal call_condition_sense : std_logic;                -- '0'=CFc (false), '1'=CTc (true)
    signal call_unconditional : std_logic;                  -- '1' for CALL (unconditional), '0' for conditional

    -- Conditional RET signals
    signal ret_condition : std_logic_vector(1 downto 0);   -- Condition code for RET (00=carry, 01=zero, 10=sign, 11=parity)
    signal ret_condition_sense : std_logic;                 -- '0'=RFc (false), '1'=RTc (true)
    signal ret_unconditional : std_logic;                   -- '1' for RET (unconditional), '0' for conditional

    -- I/O operation signals
    signal is_inp_op : std_logic := '0';                    -- '1' when INP instruction decoded
    signal is_out_op : std_logic := '0';                    -- '1' when OUT instruction decoded
    signal io_port_addr : std_logic_vector(4 downto 0);     -- Port address (3-bit for INP, 5-bit for OUT)

    -- Variable-length cycle control
    -- Per Intel 8008 datasheet: "Many of the instructions for the 8008 are multi-cycle
    -- and do not require the two execution states, T4 and T5. As a result, these states
    -- are omitted when they are not needed and the 8008 operates asynchronously with
    -- respect to the cycle length."
    -- When skip_exec_states='1', T3 transitions directly to T1 (3-state cycle)
    -- When skip_exec_states='0', T3 transitions to T4->T5->T1 (5-state cycle)
    signal skip_exec_states : std_logic := '1';  -- Runtime control: is current cycle 3-state or 5-state?

    -- SILICON-ACCURATE: Separate combinatorial decode signal
    -- In real 8008, PLA decoder determines cycle length combinatorially
    -- This signal represents the PLA output that feeds the timing state machine
    signal instruction_needs_execute : std_logic;  -- Combinatorial: does decoded instruction need 5-state EXECUTE?

begin

    --===========================================
    -- Instruction Cycle Length Decoder (SILICON-ACCURATE)
    --===========================================
    -- This represents the PLA decoder logic in the real 8008
    -- It's purely combinatorial - output changes immediately when instruction_reg changes
    -- Determines if the current instruction needs a 5-state EXECUTE cycle
    --
    -- IMPORTANT: This mimics real 8008 hardware where the PLA decoder outputs
    -- directly control the timing state machine cycle length decision
    --
    -- CRITICAL: Only decode during INSTRUCTION fetch (PCI cycle), NOT during data reads
    -- The instruction_reg may contain DATA bytes during IMMEDIATE/MEM_READ cycles
    process(instruction_reg, microcode_state, cycle_type_reg, is_load_op, is_alu_op, is_immediate,
            src_is_memory, dst_is_memory)
    begin
        -- Default: no execute cycle needed (3-state operations)
        instruction_needs_execute <= '0';

        -- Only decode during FETCH state AND instruction fetch cycle (PCI)
        -- This prevents decoding of DATA bytes that temporarily occupy instruction_reg
        if microcode_state = FETCH and cycle_type_reg = "00" then
            -- Check if this is a register-to-register MOV
            if is_load_op = '1' and is_immediate = '0' and
               src_is_memory = '0' and dst_is_memory = '0' then
                instruction_needs_execute <= '1';  -- MOV Rx,Ry needs 5-state EXECUTE
            -- Check if this is a register-operand ALU operation
            elsif is_alu_op = '1' and is_immediate = '0' and src_is_memory = '0' then
                instruction_needs_execute <= '1';  -- ALU Rx needs 5-state EXECUTE
            end if;
        end if;
    end process;

    --===========================================
    -- ALU Instantiation
    --===========================================
    -- Combinational logic unit for arithmetic and logical operations
    alu_inst: i8008_alu
        port map (
            data_0 => alu_data_0,
            data_1 => alu_data_1,
            flag_carry => flag_carry,
            command => alu_command,
            alu_result => alu_result
        );

    --===========================================
    -- Combinational Rotate Logic
    --===========================================
    -- Implements the four rotate instructions:
    --   RLC (000): Rotate Left Circular - bit7 -> bit0 and carry
    --   RRC (001): Rotate Right Circular - bit0 -> bit7 and carry
    --   RAL (010): Rotate Left through carry - 9-bit rotation
    --   RAR (011): Rotate Right through carry - 9-bit rotation
    process(rotate_type, registers, rotate_saved_carry)
        variable accumulator : std_logic_vector(7 downto 0);
    begin
        accumulator := registers(REG_A);

        case rotate_type is
            when "000" =>  -- RLC: Rotate Left Circular
                rotate_result(7 downto 1) <= accumulator(6 downto 0);
                rotate_result(0) <= accumulator(7);
                rotate_carry <= accumulator(7);

            when "001" =>  -- RRC: Rotate Right Circular
                rotate_result(6 downto 0) <= accumulator(7 downto 1);
                rotate_result(7) <= accumulator(0);
                rotate_carry <= accumulator(0);

            when "010" =>  -- RAL: Rotate Left through Carry
                rotate_result(7 downto 1) <= accumulator(6 downto 0);
                rotate_result(0) <= rotate_saved_carry;
                rotate_carry <= accumulator(7);

            when "011" =>  -- RAR: Rotate Right through Carry
                rotate_result(6 downto 0) <= accumulator(7 downto 1);
                rotate_result(7) <= rotate_saved_carry;
                rotate_carry <= accumulator(0);

            when others =>
                rotate_result <= (others => '0');
                rotate_carry <= '0';
        end case;
    end process;

    --===========================================
    -- Clock Phase Counter
    --===========================================
    -- Toggles every φ1 rising edge to create two-clock-period state timing
    -- This divides the state machine transitions in half:
    --   - First clock period (clock_phase='0'): Setup actions
    --   - Second clock period (clock_phase='1'): State transitions

    process(phi1, reset_n)
    begin
        if reset_n = '0' then
            clock_phase <= '1';  -- Reset to '1' so SYNC starts at '0'
        elsif rising_edge(phi1) then
            clock_phase <= not clock_phase;
            if DEBUG_VERBOSE then
                report "Clock phase toggled to " & std_logic'image(not clock_phase) & " at " & time'image(now);
            end if;
        end if;
    end process;

    --===========================================
    -- SYNC Signal Generation
    --===========================================
    -- Per Intel 8008 datasheet Figure 15:
    -- SYNC is HIGH during first clock period of ANY state (when clock_phase='0')
    -- SYNC is LOW during second clock period of ANY state (when clock_phase='1')
    -- This makes SYNC a true "divide by two" signal that distinguishes between
    -- the two clock periods within EVERY state (T1, T2, T3, T4, T5)
    -- During reset, clock_phase='1' so SYNC='0'

    SYNC <= '0' when reset_n = '0' else not clock_phase;

    --===========================================
    -- State Output Encoding (S2, S1, S0)
    --===========================================
    -- Per Intel 8008 datasheet Table 1

    process(timing_state)
    begin
        case timing_state is
            when T1      => S2 <= '0'; S1 <= '0'; S0 <= '0';  -- 000
            when T1I     => S2 <= '0'; S1 <= '0'; S0 <= '1';  -- 001
            when T2      => S2 <= '0'; S1 <= '1'; S0 <= '0';  -- 010
            when TWAIT   => S2 <= '0'; S1 <= '1'; S0 <= '1';  -- 011
            when T3      => S2 <= '1'; S1 <= '0'; S0 <= '0';  -- 100
            when STOPPED => S2 <= '1'; S1 <= '0'; S0 <= '1';  -- 101
            when T4      => S2 <= '1'; S1 <= '1'; S0 <= '0';  -- 110
            when T5      => S2 <= '1'; S1 <= '1'; S0 <= '1';  -- 111
        end case;
    end process;

    --===========================================
    -- Timing State Machine
    --===========================================
    -- Implements the real 8008 hardware state sequencing
    -- Each state lasts TWO clock periods (4.4µs)
    -- Free-running: Always cycles T1→T2→T3→T4→T5→T1...

    process(phi1, reset_n)
        variable next_phase : std_logic;
    begin
        if reset_n = '0' then
            timing_state <= T1;

        elsif rising_edge(phi1) then
            -- Get next clock phase value immediately
            next_phase := not clock_phase;

            -- State transitions occur on second clock period only
            if next_phase = '1' then
                case timing_state is
                    when T1 =>
                        -- Check for interrupt request
                        if INT = '1' then
                            timing_state <= T1I;
                            report "T1 -> T1I (interrupt)";
                        else
                            timing_state <= T2;
                            report "T1 -> T2";
                        end if;

                    when T1I =>
                        timing_state <= T2;
                        report "T1I -> T2";

                    when T2 =>
                        -- Check READY signal for wait states
                        if READY = '1' then
                            timing_state <= T3;
                            report "T2 -> T3";
                        else
                            timing_state <= TWAIT;
                            report "T2 -> TWAIT";
                        end if;

                    when TWAIT =>
                        -- Stay in wait until READY
                        if READY = '1' then
                            timing_state <= T3;
                            report "TWAIT -> T3";
                        end if;

                    when T3 =>
                        -- Variable-length cycles per Intel 8008 datasheet
                        -- Most instructions don't need T4/T5 execution states
                        --
                        -- SILICON-ACCURATE: Use combinatorial decoder output during FETCH
                        -- In real 8008, PLA decoder directly drives timing state machine
                        if microcode_state = FETCH then
                            -- Instruction just fetched - use combinatorial decode
                            if is_halt_op = '1' then
                                timing_state <= STOPPED;
                                report "T3 -> STOPPED (HLT instruction)";
                            elsif instruction_needs_execute = '1' then
                                timing_state <= T4;
                                report "T3 -> T4 (5-state cycle - instruction needs EXECUTE)";
                            else
                                timing_state <= T1;
                                report "T3 -> T1 (3-state cycle - no EXECUTE needed)";
                            end if;
                        else
                            -- Other microcode states - use runtime tracking
                            if skip_exec_states = '1' then
                                timing_state <= T1;
                                report "T3 -> T1 (3-state cycle)";
                            else
                                timing_state <= T4;
                                report "T3 -> T4 (5-state cycle)";
                            end if;
                        end if;

                    when T4 =>
                        timing_state <= T5;
                        report "T4 -> T5";

                    when T5 =>
                        -- Return to T1 after execution states
                        timing_state <= T1;
                        report "T5 -> T1 (cycle complete)";

                    when STOPPED =>
                        -- Remain stopped (HLT instruction executed)
                        null;
                end case;
            end if;
        end if;
    end process;

    --===========================================
    -- Cycle Type Decode
    --===========================================
    -- Determine if current cycle is read or write
    -- Per Intel 8008 datasheet:
    --   00 (PCI) = Program memory read (instruction fetch) - READ
    --   01 (PCR) = Program memory read (data) - READ
    --   10 (PCW) = Program memory write (data) - WRITE
    --   11 (PCC) = I/O or stack (not used in basic implementation) - varies

    is_read_cycle <= '1' when (cycle_type_reg = "00" or cycle_type_reg = "01") else '0';

    --===========================================
    -- Data Bus Multiplexing
    --===========================================
    -- Per Intel 8008 datasheet:
    --   T1 state: D7-D0 = A7-A0 (lower 8 bits of address) - CPU drives
    --   T2 state: D7-D6 = cycle type, D5-D0 = A13-A8 (upper 6 bits of address) - CPU drives
    --   T3 state: D7-D0 = data (bidirectional)
    --             - CPU drives bus during WRITE cycles (PCW)
    --             - Memory/IO drives bus during READ cycles (PCI, PCR)
    --   Other states: Hi-Z (bus not driven by CPU)
    --
    -- For memory operations (M register), use memory_address instead of program_counter

    process(timing_state, program_counter, memory_address, microcode_state, cycle_type_reg, data_out, is_read_cycle)
        variable effective_address : unsigned(13 downto 0);
    begin
        -- Select address source: PC for instruction fetch, memory_address for M register ops
        if microcode_state = MEM_READ or microcode_state = MEM_WRITE then
            effective_address := memory_address;
        else
            effective_address := program_counter;
        end if;

        case timing_state is
            when T1 | T1I =>
                -- Output lower 8 bits of address
                data_bus_output <= std_logic_vector(effective_address(7 downto 0));
                data_bus_enable <= '1';

            when T2 =>
                -- Output cycle type (D7-D6) and upper 6 bits of address (D5-D0)
                data_bus_output <= cycle_type_reg & std_logic_vector(effective_address(13 downto 8));
                data_bus_enable <= '1';

            when T3 =>
                -- Bidirectional data transfer
                if is_read_cycle = '1' then
                    -- READ: Hi-Z (memory drives the bus)
                    data_bus_output <= (others => '0');
                    data_bus_enable <= '0';
                else
                    -- WRITE: CPU drives the bus
                    data_bus_output <= data_out;
                    data_bus_enable <= '1';
                end if;

            when others =>
                -- Hi-Z during T4, T5, TWAIT, STOPPED
                data_bus_output <= (others => '0');
                data_bus_enable <= '0';
        end case;
    end process;

    -- Tri-state buffer control
    data_bus <= data_bus_output when data_bus_enable = '1' else (others => 'Z');

    --===========================================
    -- Data Input Capture
    --===========================================
    -- Latch data from bus during T3 of read cycles
    -- Per Intel 8008: data is valid during T3 and latched on phi2 rising edge
    process(phi2, reset_n)
    begin
        if reset_n = '0' then
            data_in <= (others => '0');
            instruction_reg <= (others => '0');
        elsif rising_edge(phi2) then
            -- Capture data during T3 of read cycles
            if timing_state = T3 and is_read_cycle = '1' then
                data_in <= data_bus;

                -- If this is an instruction fetch (PCI), also update instruction register
                if cycle_type_reg = "00" then
                    instruction_reg <= data_bus;
                    report "Instruction fetched: 0x" & to_hstring(unsigned(data_bus));
                end if;
            end if;
        end if;
    end process;

    --===========================================
    -- Register File Access
    --===========================================
    -- Combinational read, synchronous write
    -- This models the real 8008 register file hardware

    -- Read logic (combinational)
    reg_read_data <= registers(reg_read_addr);

    -- Write logic (synchronous on phi2)
    -- Writes happen when microcode sequencer asserts reg_write_enable
    -- Using phi2 allows microcode sequencer (on phi1) to set reg_write_enable first
    process(phi2, reset_n)
    begin
        if reset_n = '0' then
            registers <= (others => (others => '0'));
        elsif rising_edge(phi2) then
            if reg_write_enable = '1' then
                registers(reg_write_addr) <= reg_write_data;
                report "Register write: R" & integer'image(reg_write_addr) &
                       " <= 0x" & to_hstring(unsigned(reg_write_data));
            end if;
        end if;
    end process;

    --===========================================
    -- ALU Operand Multiplexing
    --===========================================
    -- Connect register file, immediate data, and memory data to ALU inputs
    process(registers, src_reg, data_in, immediate_data, is_immediate, src_is_memory)
    begin
        -- Operand 0 is always the accumulator
        alu_data_0 <= registers(REG_A);

        -- Operand 1 comes from source register, immediate data, or memory
        if is_immediate = '1' then
            alu_data_1 <= immediate_data;  -- Use saved immediate byte
        elsif src_is_memory = '1' then
            alu_data_1 <= data_in;  -- Memory data from bus
        else
            alu_data_1 <= registers(to_integer(unsigned(src_reg)));  -- Register operand
        end if;
    end process;

    --===========================================
    -- Flag Update Logic
    --===========================================
    -- Updates condition flags based on ALU results
    -- Only updates during ALU operations
    process(phi1, reset_n)
        variable result_byte : std_logic_vector(7 downto 0);
        variable parity_count : integer;
    begin
        if reset_n = '0' then
            flag_carry <= '0';
            flag_zero <= '0';
            flag_sign <= '0';
            flag_parity <= '0';
            rotate_saved_carry <= '0';
        elsif rising_edge(phi1) then
            -- Continuously capture current carry flag for rotate operations
            -- This breaks the combinational loop by registering the value
            rotate_saved_carry <= flag_carry;

            -- Update carry flag for rotate operations (on next phi1 after rotate executes on phi2)
            -- Rotate executes at end of T3 on phi2, so flag update happens on next phi1 (early T1 or T4)
            if is_rotate_op = '1' and timing_state = T3 and clock_phase = '1' then
                flag_carry <= rotate_carry;
            elsif is_alu_op = '1' and timing_state = T5 and clock_phase = '0' then
                result_byte := alu_result(7 downto 0);

                -- Carry flag (bit 8 of ALU result)
                flag_carry <= alu_result(8);

                -- Zero flag (result is all zeros)
                if result_byte = x"00" then
                    flag_zero <= '1';
                else
                    flag_zero <= '0';
                end if;

                -- Sign flag (bit 7 of result)
                flag_sign <= result_byte(7);

                -- Parity flag (even parity = 1)
                parity_count := 0;
                for i in 0 to 7 loop
                    if result_byte(i) = '1' then
                        parity_count := parity_count + 1;
                    end if;
                end loop;
                if (parity_count mod 2) = 0 then
                    flag_parity <= '1';
                else
                    flag_parity <= '0';
                end if;

                report "Flags updated: C=" & std_logic'image(alu_result(8)) &
                       " Z=" & std_logic'image(flag_zero) &
                       " S=" & std_logic'image(result_byte(7)) &
                       " P=" & std_logic'image(flag_parity);
            end if;
        end if;
    end process;

    --===========================================
    -- Memory Address Formation
    --===========================================
    -- Form 14-bit address from H:L register pair for M register operations
    -- Per Intel 8008 datasheet: H contains upper 6 bits, L contains lower 8 bits
    memory_address <= unsigned(registers(REG_H)(5 downto 0)) & unsigned(registers(REG_L));

    --===========================================
    -- Instruction Decoder (PLA)
    --===========================================
    -- Decodes instruction_reg into control signals
    -- This is combinational logic (like a real PLA)
    -- Per Intel 8008 datasheet instruction encoding
    process(instruction_reg)
        variable opcode : std_logic_vector(7 downto 0);
    begin
        opcode := instruction_reg;

        -- DEBUG: Log every decoder invocation
        report "DECODER: instruction_reg=0x" & to_hstring(unsigned(instruction_reg)) &
               " bits[7:6]=" & std_logic'image(instruction_reg(7)) & std_logic'image(instruction_reg(6));

        -- Default values (all operations disabled)
        is_alu_op <= '0';
        is_load_op <= '0';
        is_jump_op <= '0';
        is_call_op <= '0';
        is_ret_op <= '0';
        is_halt_op <= '0';
        is_immediate <= '0';
        is_rotate_op <= '0';
        rotate_type <= "000";
        src_reg <= "000";
        dst_reg <= "000";
        alu_command <= "000";
        src_is_memory <= '0';
        dst_is_memory <= '0';
        jump_unconditional <= '0';
        jump_condition <= "00";
        jump_condition_sense <= '0';
        call_unconditional <= '0';
        call_condition <= "00";
        call_condition_sense <= '0';
        ret_unconditional <= '0';
        ret_condition <= "00";
        ret_condition_sense <= '0';
        is_inp_op <= '0';
        is_out_op <= '0';
        io_port_addr <= "00000";

        -- Decode opcode
        -- Intel 8008 instruction format:
        -- Bits 7-6: Instruction class
        -- Bits 5-3: Destination register (for register ops)
        -- Bits 2-0: Source register (for register ops)
        -- Register encoding: 000-110 = A,B,C,D,E,H,L; 111 = M (memory via H:L)

        case opcode(7 downto 6) is
            when "00" =>
                -- Class 00: HLT, Rotate, Conditional Return, MVI (Load Immediate), ALU Immediate, Inc/Dec
                if opcode = x"00" or opcode = x"FF" then
                    -- HLT (00000000 or 11111111)
                    is_halt_op <= '1';
                elsif opcode(2 downto 0) = "010" and opcode(5 downto 3) <= "011" then
                    -- Rotate instructions: 00 FFF 010
                    -- FFF: 000=RLC, 001=RRC, 010=RAL, 011=RAR (only 000-011 are valid)
                    is_rotate_op <= '1';
                    rotate_type <= opcode(5 downto 3);
                elsif opcode(2 downto 0) = "110" then
                    -- MVI (Move Immediate to register): 00 DDD 110 (source field = 110)
                    -- This is followed by an immediate byte
                    -- Destination register is in bits 5:3 (can be any register including L=110)
                    dst_reg <= opcode(5 downto 3);
                    src_reg <= "000";  -- Don't care
                    is_load_op <= '1';
                    is_immediate <= '1';
                elsif opcode(2 downto 0) = "100" then
                    -- Immediate ALU operations: 00 FFF 100 + immediate byte
                    -- Per Intel 8008 datasheet: ADI, ACI, SUI, SBI, NDI, XRI, ORI, CPI
                    -- Bits 5-3: ALU function (FFF)
                    -- Followed by immediate data byte
                    is_alu_op <= '1';
                    is_immediate <= '1';
                    alu_command <= opcode(5 downto 3);
                    dst_reg <= "000";  -- Accumulator is destination
                elsif opcode(2 downto 0) = "111" then
                    -- 00 XXX 111 = RET (unconditional return)
                    is_ret_op <= '1';
                    ret_unconditional <= '1';
                    report "Decoded as RET (unconditional)";
                elsif opcode(2 downto 0) = "011" then
                    -- 00 CCC 011 = Conditional RET
                    -- Bits 5:3=CCC: condition code with sense bit
                    -- Same encoding as conditional jumps: bit[5]=sense, bits[4:3]=condition
                    is_ret_op <= '1';
                    ret_unconditional <= '0';
                    ret_condition <= opcode(4 downto 3);      -- C4C3: 00=carry, 01=zero, 10=sign, 11=parity
                    ret_condition_sense <= opcode(5);          -- 0=RFc (false), 1=RTc (true)
                    report "Decoded as conditional RET (CCC=" &
                           std_logic'image(opcode(5)) & std_logic'image(opcode(4)) & std_logic'image(opcode(3)) & ")";
                end if;
                -- NOTE: Inc/Dec operations will be implemented here later

            when "01" =>
                -- Class 01: Jump, Call, and Return instructions
                -- All jumps/calls/returns have bits[7:6]="01"
                -- Per 8008UM.pdf Table: bits[2:0] determine the operation
                report "Class 01 instruction decoded: opcode=0x" & to_hstring(unsigned(opcode)) &
                       " bits[2:0]=" & std_logic'image(opcode(2)) & std_logic'image(opcode(1)) & std_logic'image(opcode(0));
                if opcode(2 downto 0) = "100" then
                    -- 01 XXX 100 = JMP (unconditional jump)
                    is_jump_op <= '1';
                    jump_unconditional <= '1';
                    report "Decoded as JMP (unconditional)";
                elsif opcode(2 downto 0) = "000" then
                    -- 01 SC₄C₃ 000 = Conditional jump (bit[2]=0, bit[1:0]=00)
                    -- bit[5]=S: 0=JFc (false), 1=JTc (true)
                    -- bits[4:3]=C₄C₃: condition code
                    is_jump_op <= '1';
                    jump_unconditional <= '0';
                    jump_condition <= opcode(4 downto 3);      -- C4C3: 00=carry, 01=zero, 10=sign, 11=parity
                    jump_condition_sense <= opcode(5);          -- 0=JFc (false), 1=JTc (true)
                elsif opcode(2 downto 0) = "110" then
                    -- 01 XXX 110 = CALL (unconditional)
                    is_call_op <= '1';
                    call_unconditional <= '1';
                    report "Decoded as CALL (unconditional)";
                elsif opcode(2 downto 0) = "010" then
                    -- 01 CCC 010 = Conditional CALL
                    -- bit[5:3]=CCC: condition code with sense bit
                    -- Same encoding as conditional jumps: bit[5]=sense, bits[4:3]=condition
                    is_call_op <= '1';
                    call_unconditional <= '0';
                    call_condition <= opcode(4 downto 3);      -- C4C3: 00=carry, 01=zero, 10=sign, 11=parity
                    call_condition_sense <= opcode(5);          -- 0=CFc (false), 1=CTc (true)
                    report "Decoded as conditional CALL (CCC=" &
                           std_logic'image(opcode(5)) & std_logic'image(opcode(4)) & std_logic'image(opcode(3)) & ")";
                elsif opcode(2 downto 0) = "111" then
                    -- 01 XXX 111 = RET
                    is_ret_op <= '1';
                elsif opcode(0) = '1' then
                    -- 01 XXX XX1 = I/O instructions (INP or OUT)
                    -- INP: 01 00M MM1 (bits 5:4 = 00)
                    -- OUT: 01 RRM MM1 (bits 5:4 ≠ 00)
                    if opcode(5 downto 4) = "00" then
                        -- INP: Read from input port into accumulator
                        is_inp_op <= '1';
                        io_port_addr <= "00" & opcode(3 downto 1);  -- 3-bit port address (extended to 5 bits)
                        report "Decoded as INP (port=" & integer'image(to_integer(unsigned(opcode(3 downto 1)))) & ")";
                    else
                        -- OUT: Write accumulator to output port
                        is_out_op <= '1';
                        io_port_addr <= opcode(5 downto 1);  -- 5-bit port address
                        report "Decoded as OUT (port=" & integer'image(to_integer(unsigned(opcode(5 downto 1)))) & ")";
                    end if;
                end if;

            when "10" =>
                -- Class 10: ALU operations (register operand)
                -- Bits 5-3: ALU function
                -- Bits 2-0: Source register
                is_alu_op <= '1';
                alu_command <= opcode(5 downto 3);
                src_reg <= opcode(2 downto 0);
                dst_reg <= "000";  -- Accumulator is destination

                -- Check for memory reference as source operand
                if opcode(2 downto 0) = "111" then
                    src_is_memory <= '1';
                end if;

            when "11" =>
                -- Class 11: MOV (register-to-register and register-memory)
                -- Format: 11 DDD SSS
                -- Bits 5-3: Destination register (DDD)
                -- Bits 2-0: Source register (SSS)
                -- Per Intel 8008 datasheet: ALL class 11 instructions are MOV

                -- MOV operations (register-to-register or register-memory)
                dst_reg <= opcode(5 downto 3);
                src_reg <= opcode(2 downto 0);
                is_load_op <= '1';

                -- Check for memory reference (M register = 111)
                if opcode(2 downto 0) = "111" then
                    src_is_memory <= '1';
                end if;
                if opcode(5 downto 3) = "111" then
                    dst_is_memory <= '1';
                end if;

            when others =>
                -- Other instruction classes
                null;
        end case;
    end process;

    --===========================================
    -- Microcode Sequencer
    --===========================================
    -- Orchestrates multi-cycle instruction execution
    -- This is cycle-by-cycle control, NOT behavioral execution
    process(phi1, reset_n)
        variable condition_met : std_logic;  -- For evaluating jump conditions
    begin
        if reset_n = '0' then
            microcode_state <= FETCH;
            reg_write_enable <= '0';
            reg_write_addr <= 0;
            reg_write_data <= (others => '0');
            reg_read_addr <= 0;
            cycle_type_reg <= "00";  -- PCI (instruction fetch)
            skip_exec_states <= '1';  -- Default to 3-state cycles
            perform_jump <= '0';  -- Initialize jump control
            pc_increment_extra <= '0';  -- Initialize extra increment flag

        elsif rising_edge(phi1) then
            -- Default: no register writes
            reg_write_enable <= '0';

            -- Debug: log state at every phi1 edge during T5
            if timing_state = T5 then
                report "At T5 phi1 edge: clock_phase=" & std_logic'image(clock_phase) &
                       " skip_exec=" & std_logic'image(skip_exec_states) &
                       " microcode=" & microcode_state_t'image(microcode_state);
            end if;

            -- Microcode state transitions happen at end of cycle
            -- For 3-state cycles: end of T3
            -- For 5-state cycles: end of T5
            --
            -- IMPORTANT: We need to handle BOTH cases:
            --   1. End of T3 with skip_exec='1' --> microcode transition (3-state cycle done)
            --   2. End of T3 with skip_exec='0' --> NO transition, go to T4 (5-state cycle continues)
            --
            -- The timing state machine handles T3->T4 vs T3->T1 based on skip_exec_states
            -- Here we only need to handle microcode transitions at END of complete cycles
            -- Microcode state transitions happen at end of cycle
            -- Original logic was: "if timing_state = T3 and skip_exec_states = '1'"
            -- But this creates chicken-egg problem: we can't set skip_exec_states until we decode,
            -- but the condition requires it to be '1' to enter the decode logic!
            --
            -- FIX: Always enter at T3 end during FETCH, set skip_exec_states INSIDE based on decode
            --      Also enter at T5 end for 5-state cycles that need to complete
            if (timing_state = T3 and clock_phase = '0' and microcode_state = FETCH) or
               (timing_state = T3 and clock_phase = '0' and skip_exec_states = '1' and microcode_state /= FETCH) or
               (timing_state = T5 and clock_phase = '0' and skip_exec_states = '0') then

                report "Microcode handler entered: timing_state=" & timing_state_t'image(timing_state) &
                       " clock_phase=" & std_logic'image(clock_phase) &
                       " skip_exec=" & std_logic'image(skip_exec_states) &
                       " microcode_state=" & microcode_state_t'image(microcode_state);

                case microcode_state is
                    when FETCH =>
                        -- Just fetched an instruction (3-state PCI cycle completed)
                        -- PLA control signals are now valid
                        pc_should_increment <= '1';  -- Default: PC should increment (override for M register ops)
                        perform_jump <= '0';  -- Reset jump flag (will be set if jump/call/ret occurs)
                        pc_increment_extra <= '0';  -- Clear extra increment flag after use
                        if is_halt_op = '1' then
                            -- HLT instruction - stop execution
                            report "HLT instruction detected - entering STOPPED state";
                            microcode_state <= FETCH;
                            skip_exec_states <= '1';  -- Stay in 3-state cycles

                        elsif is_rotate_op = '1' then
                            -- Rotate instruction (RLC, RRC, RAL, RAR)
                            -- NOTE: flag_carry update happens in phi1 process to avoid multiple drivers
                            reg_write_enable <= '1';
                            reg_write_addr <= REG_A;
                            reg_write_data <= rotate_result;
                            microcode_state <= FETCH;
                            skip_exec_states <= '1';
                            report "Rotate operation: type=" & to_string(rotate_type) &
                                   " A=0x" & to_hstring(unsigned(registers(REG_A))) &
                                   " -> 0x" & to_hstring(unsigned(rotate_result)) &
                                   " carry=" & std_logic'image(rotate_carry);

                        elsif is_alu_op = '1' then
                            if is_immediate = '1' then
                                -- Need to fetch immediate byte first (3-state PCR cycle)
                                cycle_type_reg <= "01";  -- PCR (data read)
                                microcode_state <= IMMEDIATE;
                                skip_exec_states <= '1';  -- 3-state cycle for data fetch
                            elsif src_is_memory = '1' then
                                -- ALU with memory operand - need to read from memory first
                                --  Use 5-state cycle: T1-T2-T3 for memory read, T4-T5 for execution
                                cycle_type_reg <= "01";  -- PCR (data read)
                                microcode_state <= MEM_READ;
                                skip_exec_states <= '0';  -- 5-state cycle: read M then execute
                                pc_should_increment <= '0';  -- Don't increment PC for M register read
                                report "ALU with M register source - initiating 5-state memory read+execute";
                            else
                                -- ALU with register operand - execute immediately
                                microcode_state <= EXECUTE;
                                skip_exec_states <= '0';  -- 5-state cycle for execution
                                pc_should_increment <= '0';  -- Don't increment PC during EXECUTE (already incremented when fetching instruction)
                            end if;

                        elsif is_load_op = '1' then
                            -- MOV/LrI operation - check for immediate or memory references
                            if is_immediate = '1' then
                                -- LrI (Load register Immediate) - fetch immediate byte
                                --  PC should increment after fetching instruction, then again after fetching immediate
                                pc_should_increment <= '1';  -- Allow PC to increment now (for instruction fetch)
                                cycle_type_reg <= "01";  -- PCR (data read)
                                microcode_state <= IMMEDIATE;
                                skip_exec_states <= '1';  -- 3-state cycle for immediate fetch
                                report "LrI (Load register Immediate) - fetching immediate byte";
                            elsif src_is_memory = '1' and dst_is_memory = '0' then
                                -- Load from memory to register (e.g., MOV B,M)
                                -- Use 5-state cycle for memory read (per Intel 8008: 8 states total = 3 PCI + 5 for load)
                                cycle_type_reg <= "01";  -- PCR (data read)
                                microcode_state <= MEM_READ;
                                skip_exec_states <= '0';  -- 5-state cycle for memory read
                                pc_should_increment <= '0';  -- Don't increment PC for M register read
                                report "MOV from memory - initiating 5-state memory read";
                            elsif dst_is_memory = '1' and src_is_memory = '0' then
                                -- Store register to memory (e.g., MOV M,B)
                                -- Use 5-state cycle for memory write (per Intel 8008: 8 states total = 3 PCI + 5 for store)
                                cycle_type_reg <= "10";  -- PCW (data write)
                                microcode_state <= MEM_WRITE;
                                skip_exec_states <= '0';  -- 5-state cycle for memory write
                                pc_should_increment <= '0';  -- Don't increment PC for M register write
                                data_out <= registers(to_integer(unsigned(src_reg)));
                                report "MOV to memory - initiating 5-state memory write";
                            elsif src_is_memory = '1' and dst_is_memory = '1' then
                                -- M to M is illegal (both can't be memory)
                                report "ERROR: Illegal M to M operation" severity error;
                                microcode_state <= FETCH;
                                cycle_type_reg <= "00";  -- PCI (next instruction fetch)
                                skip_exec_states <= '1';  -- 3-state cycle
                            else
                                -- Regular register-to-register move
                                report "MOV register-to-register detected - setting skip_exec='0' for 5-state EXECUTE";
                                microcode_state <= EXECUTE;
                                skip_exec_states <= '0';  -- 5-state cycle for register transfer
                                pc_should_increment <= '0';  -- Don't increment PC during EXECUTE (already incremented when fetching instruction)
                            end if;

                        elsif is_jump_op = '1' then
                            -- Jump instruction - need to fetch 2 address bytes
                            cycle_type_reg <= "01";  -- PCR (data read)
                            microcode_state <= ADDR_LOW;
                            skip_exec_states <= '1';  -- 3-state cycle for address fetch
                            report "Jump instruction - fetching address low byte";

                        elsif is_call_op = '1' then
                            -- CALL instruction - need to fetch 2 address bytes, then push PC
                            cycle_type_reg <= "01";  -- PCR (data read)
                            microcode_state <= ADDR_LOW;
                            skip_exec_states <= '1';  -- 3-state cycle for address fetch
                            report "CALL instruction - fetching address low byte";

                        elsif is_ret_op = '1' then
                            -- RET instruction (unconditional or conditional)
                            -- Check if this is conditional or unconditional RET
                            if ret_unconditional = '1' then
                                -- Unconditional RET - always pop and return
                                jump_addr_low <= std_logic_vector(address_stack(to_integer(stack_pointer))(7 downto 0));
                                jump_addr_high <= std_logic_vector(address_stack(to_integer(stack_pointer))(13 downto 8));
                                stack_pointer <= stack_pointer - 1;
                                perform_jump <= '1';  -- Use jump mechanism to load PC
                                report "RET (unconditional): Popping PC from stack[" & integer'image(to_integer(stack_pointer)) &
                                       "] = 0x" & to_hstring(address_stack(to_integer(stack_pointer)));
                            else
                                -- Conditional RET - evaluate condition
                                -- Condition codes (C4C3): 00=carry, 01=zero, 10=sign, 11=parity
                                case ret_condition is
                                    when "00" => condition_met := flag_carry;   -- Carry flag
                                    when "01" => condition_met := flag_zero;    -- Zero flag
                                    when "10" => condition_met := flag_sign;    -- Sign flag
                                    when "11" => condition_met := flag_parity;  -- Parity flag
                                    when others => condition_met := '0';
                                end case;

                                -- For RTc (sense='1'): return if condition is true
                                -- For RFc (sense='0'): return if condition is false
                                if (ret_condition_sense = '1' and condition_met = '1') or
                                   (ret_condition_sense = '0' and condition_met = '0') then
                                    -- Condition met - pop and return
                                    jump_addr_low <= std_logic_vector(address_stack(to_integer(stack_pointer))(7 downto 0));
                                    jump_addr_high <= std_logic_vector(address_stack(to_integer(stack_pointer))(13 downto 8));
                                    stack_pointer <= stack_pointer - 1;
                                    perform_jump <= '1';
                                    report "Conditional RET condition MET - popping PC from stack[" & integer'image(to_integer(stack_pointer)) &
                                           "] = 0x" & to_hstring(address_stack(to_integer(stack_pointer)));
                                else
                                    -- Condition not met - do nothing, continue execution
                                    perform_jump <= '0';
                                    report "Conditional RET condition NOT MET - continuing execution";
                                end if;
                            end if;
                            -- Return to fetch next instruction (at popped address if jumped, or next sequential if not)
                            microcode_state <= FETCH;
                            cycle_type_reg <= "00";  -- PCI (next instruction fetch)
                            skip_exec_states <= '1';  -- 3-state cycle

                        elsif is_inp_op = '1' then
                            -- INP instruction - read from input port into accumulator
                            -- Single-byte instruction, executes in single 3-state cycle
                            reg_write_enable <= '1';
                            reg_write_addr <= REG_A;
                            reg_write_data <= port_in;
                            report "INP: A <- PORT[" & integer'image(to_integer(unsigned(io_port_addr(2 downto 0)))) &
                                   "] (value=0x" & to_hstring(unsigned(port_in)) & ")";
                            microcode_state <= FETCH;
                            cycle_type_reg <= "00";  -- PCI (next instruction fetch)
                            skip_exec_states <= '1';  -- 3-state cycle

                        elsif is_out_op = '1' then
                            -- OUT instruction - write accumulator to output port
                            -- Single-byte instruction, executes in single 3-state cycle
                            -- Output is handled combinatorially via port_out and port_out_strobe signals
                            report "OUT: PORT[" & integer'image(to_integer(unsigned(io_port_addr))) &
                                   "] <- A (value=0x" & to_hstring(unsigned(registers(REG_A))) & ")";
                            microcode_state <= FETCH;
                            cycle_type_reg <= "00";  -- PCI (next instruction fetch)
                            skip_exec_states <= '1';  -- 3-state cycle

                        else
                            -- Other instructions not yet implemented
                            report "WARNING: Unimplemented instruction" severity warning;
                            microcode_state <= FETCH;
                            cycle_type_reg <= "00";  -- PCI (next instruction fetch)
                            skip_exec_states <= '1';  -- 3-state cycle
                        end if;

                    when IMMEDIATE =>
                        -- Just fetched immediate data (3-state PCR cycle completed)
                        -- IMPORTANT: Save immediate byte now before data_in changes!
                        immediate_data <= data_in;
                        report "IMMEDIATE: Captured immediate byte 0x" & to_hstring(unsigned(data_in));

                        if is_alu_op = '1' then
                            -- ALU immediate operation - execute in next cycle
                            -- IMPORTANT: Do NOT set cycle_type_reg here! Leave it as "01" (PCR) from IMMEDIATE fetch.
                            -- Setting it to "00" (PCI) would cause instruction_reg to be overwritten during EXECUTE,
                            -- making the CPU decode the wrong instruction when EXECUTE handler runs.
                            microcode_state <= EXECUTE;
                            skip_exec_states <= '0';  -- 5-state cycle for execution
                            pc_should_increment <= '0';  -- Don't increment PC during EXECUTE (already incremented when fetching instruction and immediate)
                            report "ADI operation - transitioning to EXECUTE (5-state cycle)";
                        elsif is_load_op = '1' then
                            -- LrI (Load register Immediate) - write immediate to register
                            reg_write_enable <= '1';
                            reg_write_addr <= to_integer(unsigned(dst_reg));
                            reg_write_data <= data_in;
                            report "LrI: R" & integer'image(to_integer(unsigned(dst_reg))) &
                                   " <- 0x" & to_hstring(unsigned(data_in));
                            -- Return to fetch next instruction
                            microcode_state <= FETCH;
                            cycle_type_reg <= "00";  -- PCI (instruction fetch)
                            skip_exec_states <= '1';  -- 3-state cycle for next fetch
                        end if;

                    when MEM_READ =>
                        -- Just read data from memory
                        -- For 5-state cycle: data read at T3, execution in T4-T5, microcode runs at T5
                        -- For 3-state cycle with load: microcode runs at T3
                        -- Data is now in data_in register
                        if is_alu_op = '1' then
                            -- ALU operation with memory operand - we're at end of 5-state cycle
                            -- Write ALU result to accumulator
                            reg_write_enable <= '1';
                            reg_write_addr <= REG_A;
                            reg_write_data <= alu_result(7 downto 0);
                            report "ALU with M: A <= 0x" & to_hstring(unsigned(alu_result(7 downto 0)));
                            -- Return to fetch next instruction
                            microcode_state <= FETCH;
                            cycle_type_reg <= "00";  -- PCI (instruction fetch)
                            skip_exec_states <= '1';  -- 3-state cycle for next fetch
                            pc_should_increment <= '1';  -- Reset for next instruction fetch
                        elsif is_load_op = '1' then
                            -- MOV from memory to register - we're at end of 5-state cycle
                            -- Write data (captured at T3) to destination register
                            reg_write_enable <= '1';
                            reg_write_addr <= to_integer(unsigned(dst_reg));
                            reg_write_data <= data_in;
                            report "MOV R" & integer'image(to_integer(unsigned(dst_reg))) &
                                   " <- M[0x" & to_hstring(memory_address) & "] = 0x" & to_hstring(unsigned(data_in));
                            -- Return to fetch next instruction
                            microcode_state <= FETCH;
                            cycle_type_reg <= "00";  -- PCI (instruction fetch)
                            skip_exec_states <= '1';  -- 3-state cycle for next fetch
                            pc_should_increment <= '1';  -- Reset for next instruction fetch
                        end if;

                    when MEM_WRITE =>
                        -- Just wrote data to memory (5-state PCW cycle completed at T5)
                        report "Memory write: M[0x" & to_hstring(memory_address) & "] <- 0x" & to_hstring(unsigned(data_out));
                        -- Return to fetch next instruction
                        microcode_state <= FETCH;
                        cycle_type_reg <= "00";  -- PCI (instruction fetch)
                        skip_exec_states <= '1';  -- 3-state cycle for next fetch
                        pc_should_increment <= '1';  -- Reset for next instruction fetch

                    when EXECUTE =>
                        -- Execute the instruction (5-state cycle)
                        report "EXECUTE state handler running at end of 5-state cycle";
                        if is_alu_op = '1' then
                            -- Write ALU result to accumulator (except for CMP which only sets flags)
                            -- CMP/CPI have alu_command = "111" and should NOT modify accumulator
                            if alu_command /= "111" then
                                reg_write_enable <= '1';
                                reg_write_addr <= REG_A;
                                reg_write_data <= alu_result(7 downto 0);
                            end if;
                            report "ALU operation: 0x" & to_hstring(unsigned(alu_result(7 downto 0)));
                        elsif is_load_op = '1' then
                            -- MOV: write source register to destination register
                            reg_write_enable <= '1';
                            reg_write_addr <= to_integer(unsigned(dst_reg));
                            reg_write_data <= registers(to_integer(unsigned(src_reg)));
                            report "MOV R" & integer'image(to_integer(unsigned(dst_reg))) &
                                   " <- R" & integer'image(to_integer(unsigned(src_reg))) &
                                   " (setting reg_write_enable=1, data=0x" & to_hstring(unsigned(registers(to_integer(unsigned(src_reg))))) & ")";
                        elsif is_inp_op = '1' then
                            -- INP: Read from input port into accumulator
                            -- Port address is 3 bits (0-7) stored in io_port_addr(2:0)
                            reg_write_enable <= '1';
                            reg_write_addr <= REG_A;
                            reg_write_data <= port_in;
                            report "INP: A <- PORT[" & integer'image(to_integer(unsigned(io_port_addr(2 downto 0)))) &
                                   "] (value=0x" & to_hstring(unsigned(port_in)) & ")";
                        elsif is_out_op = '1' then
                            -- OUT: Write accumulator to output port
                            -- Port address is 5 bits (0-31) stored in io_port_addr
                            -- Note: The actual output is handled combinatorially in the output assignment section
                            report "OUT: PORT[" & integer'image(to_integer(unsigned(io_port_addr))) &
                                   "] <- A (value=0x" & to_hstring(unsigned(registers(REG_A))) & ")";
                        end if;

                        -- Return to fetch next instruction (3-state PCI cycle)
                        microcode_state <= FETCH;
                        cycle_type_reg <= "00";  -- PCI (instruction fetch)
                        skip_exec_states <= '1';  -- 3-state cycle for next fetch
                        pc_should_increment <= '1';  -- Reset for next instruction fetch

                    when ADDR_LOW =>
                        -- Just fetched low byte of address (3-state PCR cycle completed)
                        jump_addr_low <= data_in;
                        report "Jump address low byte: 0x" & to_hstring(unsigned(data_in));
                        -- Prevent PC increment at end of NEXT cycle (ADDR_HIGH)
                        -- PC WILL increment at end of THIS cycle (ADDR_LOW) using the current '1' value
                        pc_should_increment <= '0';  -- Takes effect next cycle (at ADDR_HIGH)
                        -- Fetch high byte of address
                        cycle_type_reg <= "01";  -- PCR (data read)
                        microcode_state <= ADDR_HIGH;
                        skip_exec_states <= '1';  -- 3-state cycle for address fetch

                    when ADDR_HIGH =>
                        -- Just fetched high byte of address (3-state PCR cycle completed)
                        -- Only use lower 6 bits for 14-bit address (8008 has 14-bit PC)
                        jump_addr_high <= data_in(5 downto 0);
                        report "Address high byte: 0x" & to_hstring(unsigned(data_in(5 downto 0)));

                        -- Check if this is a CALL or a JMP
                        if is_call_op = '1' then
                            -- CALL instruction (unconditional or conditional)
                            -- PC currently points to the high byte of CALL address (last byte of 3-byte CALL instruction)
                            -- Return address should be PC+1 (next instruction after CALL)

                            -- Check if this is conditional or unconditional CALL
                            if call_unconditional = '1' then
                                -- Unconditional CALL - always push and jump
                                stack_pointer <= stack_pointer + 1;
                                address_stack(to_integer(stack_pointer + 1)) <= program_counter + 1;
                                report "CALL (unconditional): Pushing PC+1=0x" & to_hstring(program_counter + 1) &
                                       " to stack[" & integer'image(to_integer(stack_pointer + 1)) & "]";
                                perform_jump <= '1';
                                report "CALL target: 0x" & to_hstring(unsigned(data_in(5 downto 0)) & unsigned(jump_addr_low));
                            else
                                -- Conditional CALL - evaluate condition
                                -- Condition codes (C4C3): 00=carry, 01=zero, 10=sign, 11=parity
                                case call_condition is
                                    when "00" => condition_met := flag_carry;   -- Carry flag
                                    when "01" => condition_met := flag_zero;    -- Zero flag
                                    when "10" => condition_met := flag_sign;    -- Sign flag
                                    when "11" => condition_met := flag_parity;  -- Parity flag
                                    when others => condition_met := '0';
                                end case;

                                -- For CTc (sense='1'): call if condition is true
                                -- For CFc (sense='0'): call if condition is false
                                if (call_condition_sense = '1' and condition_met = '1') or
                                   (call_condition_sense = '0' and condition_met = '0') then
                                    -- Condition met - push return address and jump
                                    stack_pointer <= stack_pointer + 1;
                                    address_stack(to_integer(stack_pointer + 1)) <= program_counter + 1;
                                    report "Conditional CALL condition MET - pushing PC+1=0x" & to_hstring(program_counter + 1) &
                                           " to stack[" & integer'image(to_integer(stack_pointer + 1)) & "]";
                                    perform_jump <= '1';
                                    report "CALL target: 0x" & to_hstring(unsigned(data_in(5 downto 0)) & unsigned(jump_addr_low));
                                else
                                    -- Condition not met - skip call
                                    perform_jump <= '0';
                                    -- CRITICAL: PC must increment to skip past the high address byte
                                    -- pc_should_increment was set to '0' during ADDR_LOW to prevent increment during ADDR_HIGH
                                    -- When call is NOT taken, set flag to increment PC an extra time
                                    pc_increment_extra <= '1';
                                    report "Conditional CALL condition NOT MET - skipping call (will increment PC to skip high byte)";
                                end if;
                            end if;

                        elsif is_jump_op = '1' then
                            -- Jump instruction (JMP or conditional)
                            -- Evaluate jump condition
                            -- Condition codes (C4C3): 00=carry, 01=zero, 10=sign, 11=parity
                            -- For JMP (unconditional), jump_unconditional='1'
                            if jump_unconditional = '1' then
                                -- Unconditional jump (JMP) - always jump
                                perform_jump <= '1';
                                report "Unconditional JMP - will jump to 0x" &
                                       to_hstring(unsigned(data_in(5 downto 0)) & unsigned(jump_addr_low));
                            else
                                -- Conditional jump (JFc or JTc) - evaluate condition
                                -- Check the specified condition
                                case jump_condition is
                                    when "00" => condition_met := flag_carry;   -- Carry flag
                                    when "01" => condition_met := flag_zero;    -- Zero flag
                                    when "10" => condition_met := flag_sign;    -- Sign flag
                                    when "11" => condition_met := flag_parity;  -- Parity flag
                                    when others => condition_met := '0';
                                end case;

                                -- For JTc (sense='1'): jump if condition is true
                                -- For JFc (sense='0'): jump if condition is false
                                if (jump_condition_sense = '1' and condition_met = '1') or
                                   (jump_condition_sense = '0' and condition_met = '0') then
                                    perform_jump <= '1';
                                    report "Conditional jump condition MET - will jump to 0x" &
                                           to_hstring(unsigned(data_in(5 downto 0)) & unsigned(jump_addr_low));
                                else
                                    perform_jump <= '0';
                                    -- CRITICAL: PC must increment to skip past the high address byte
                                    -- pc_should_increment was set to '0' during ADDR_LOW to prevent increment during ADDR_HIGH
                                    -- When jump is NOT taken, set flag to increment PC an extra time
                                    pc_increment_extra <= '1';
                                    report "Conditional jump condition NOT MET - will increment PC to skip high byte";
                                end if;
                            end if;
                        end if;

                        -- Return to fetch next instruction (3-state PCI cycle)
                        microcode_state <= FETCH;
                        cycle_type_reg <= "00";  -- PCI (instruction fetch)
                        skip_exec_states <= '1';  -- 3-state cycle for next fetch

                    when others =>
                        microcode_state <= FETCH;
                        cycle_type_reg <= "00";  -- PCI
                        skip_exec_states <= '1';  -- 3-state cycle
                end case;
            end if;
        end if;
    end process;

    --===========================================
    -- Program Counter Management
    --===========================================
    -- PC increments after each bus cycle
    -- For 3-state cycles: increment at end of T3
    -- For 5-state cycles: increment at end of T5
    -- For jumps: PC is loaded with jump target address
    process(phi1, reset_n)
    begin
        if reset_n = '0' then
            program_counter <= (others => '0');
        elsif rising_edge(phi1) then
            -- Debug: Log all conditions at T1 to diagnose jump issue
            if timing_state = T1 then
                report "PC jump check at T1: perform_jump=" & std_logic'image(perform_jump) &
                       " clock_phase=" & std_logic'image(clock_phase) &
                       " timing_state=" & timing_state_t'image(timing_state);
            end if;

            -- Check if we should perform a jump (set in ADDR_HIGH or RET state)
            -- Execute at T1 with clock_phase='1' (after ADDR_HIGH completes and sets perform_jump)
            -- We're at T1 but clock_phase='1' means we're about to transition to the next phase
            -- The address will not be latched yet, so updating PC here takes effect for T1 address output
            if perform_jump = '1' and timing_state = T1 and clock_phase = '1' then
                -- Load PC with jump target address (14-bit)
                program_counter <= unsigned(jump_addr_high) & unsigned(jump_addr_low);
                report "Jump executed: PC <= 0x" & to_hstring(unsigned(jump_addr_high) & unsigned(jump_addr_low));
                -- NOTE: perform_jump is cleared in the Microcode Sequencer process in the next FETCH state

            -- Handle extra PC increment for conditional jumps that are NOT taken
            -- When a conditional jump is not taken, we need to skip the high address byte that was fetched
            -- This happens at T1 of the next FETCH cycle, before the address is output
            elsif pc_increment_extra = '1' and timing_state = T1 and clock_phase = '1' then
                program_counter <= program_counter + 1;
                report "Extra PC increment to skip unused high byte: " & integer'image(to_integer(program_counter + 1));

            -- Increment PC at the end of each complete bus cycle
            -- unless we're about to jump
            elsif clock_phase = '0' then
                -- Debug: report conditions
                if timing_state = T3 or timing_state = T5 then
                    report "PC check: clock_phase=" & std_logic'image(clock_phase) &
                           " timing_state=" & timing_state_t'image(timing_state) &
                           " perform_jump=" & std_logic'image(perform_jump) &
                           " skip_exec=" & std_logic'image(skip_exec_states);
                end if;

                -- PC increment logic:
                -- - FETCH state at T3 end: always increment PC after fetching instruction
                -- - IMMEDIATE state at T3 end: always increment PC after fetching immediate byte
                -- - Other states at T3/T5 end: use pc_should_increment signal
                -- Note: Jump address fetch cycles (ADDR_LOW/ADDR_HIGH) control PC increment via pc_should_increment
                if timing_state /= STOPPED then
                    -- 3-state cycles (T1-T2-T3): increment at end of T3
                    if timing_state = T3 and skip_exec_states = '1' then
                        -- Always increment for FETCH (instruction fetch) and IMMEDIATE (data fetch)
                        if microcode_state = FETCH or microcode_state = IMMEDIATE or pc_should_increment = '1' then
                            program_counter <= program_counter + 1;
                            report "PC incremented to " & integer'image(to_integer(program_counter + 1)) & " (3-state cycle)";
                        end if;
                    -- 5-state cycles (T1-T2-T3-T4-T5): increment at end of T5 if pc_should_increment='1'
                    elsif timing_state = T5 and skip_exec_states = '0' and pc_should_increment = '1' then
                        program_counter <= program_counter + 1;
                        report "PC incremented to " & integer'image(to_integer(program_counter + 1)) & " (5-state cycle)";
                    end if;
                end if;
            end if;
        end if;
    end process;

    --===========================================
    -- I/O Port Outputs
    --===========================================
    -- Output port assignments (combinatorial)
    port_out <= registers(REG_A);  -- Always drive accumulator value
    port_out_addr <= io_port_addr;  -- Drive port address
    port_out_strobe <= '1' when (is_out_op = '1' and microcode_state = FETCH and timing_state = T3) else '0';  -- Strobe during OUT execution

    --===========================================
    -- Debug Outputs
    --===========================================
    -- Continuous assignment of internal state to debug outputs
    debug_reg_A <= registers(REG_A);
    debug_reg_B <= registers(REG_B);
    debug_reg_C <= registers(REG_C);
    debug_reg_D <= registers(REG_D);
    debug_reg_E <= registers(REG_E);
    debug_reg_H <= registers(REG_H);
    debug_reg_L <= registers(REG_L);
    debug_pc <= std_logic_vector(program_counter);
    debug_flags <= flag_parity & flag_sign & flag_zero & flag_carry;

end rtl;
