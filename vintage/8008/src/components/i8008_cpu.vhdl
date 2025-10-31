-------------------------------------------------------------------------------
-- Intel 8008 Soft Processor Core - VHDL Conversion
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Robert Rico (VHDL conversion)
-- Copyright (c) 2022-2024 Michael Kohn (original Verilog implementation)
--
-- This VHDL implementation is derived from Michael Kohn's i8008 Verilog
-- implementation. The architecture, instruction decoding, and state machine
-- follow Kohn's original design.
--
-- Original Verilog: https://www.mikekohn.net/
-- License: MIT (see LICENSE.txt)
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i8008_cpu is
    port(
        -- Two-phase clock (like real 8008)
        phi1 : in std_logic;
        phi2 : in std_logic;
        reset_n : in std_logic;

        -- Real 8008-compatible interface
        data_bus : inout std_logic_vector(7 downto 0);  -- Multiplexed address/data bus

        -- State outputs (per 8008 datasheet)
        S0 : out std_logic;
        S1 : out std_logic;
        S2 : out std_logic;
        SYNC : out std_logic;

        -- Control inputs
        READY : in std_logic;
        INT : in std_logic;

        -- Status outputs
        halted : out std_logic;

        -- Debug registers (for testbench)
        debug_reg_h : out std_logic_vector(7 downto 0);
        debug_reg_l : out std_logic_vector(7 downto 0)
    );
end i8008_cpu;

architecture rtl of i8008_cpu is
    -- Component: ALU
    component i8008_alu is
        port(
            data_0 : in std_logic_vector(7 downto 0);
            data_1 : in std_logic_vector(7 downto 0);
            flag_carry : in std_logic;
            command : in std_logic_vector(2 downto 0);
            alu_result : out std_logic_vector(8 downto 0)
        );
    end component;

    -- Registers (7 general purpose registers)
    type register_array is array(0 to 6) of std_logic_vector(7 downto 0);
    signal registers : register_array := (others => (others => '0'));

    -- HL register pair helper
    signal register_hl : std_logic_vector(15 downto 0);

    -- ALU signals
    signal alu_data_0 : std_logic_vector(7 downto 0) := (others => '0');
    signal alu_data_1 : std_logic_vector(7 downto 0) := (others => '0');
    signal alu_command : std_logic_vector(2 downto 0) := (others => '0');
    signal alu_result : std_logic_vector(8 downto 0);
    signal inc_result : std_logic_vector(7 downto 0) := (others => '0');
    signal shift_result : std_logic_vector(7 downto 0) := (others => '0');
    signal shift_carry : std_logic := '0';

    -- Call stack: 16 bit, array of 8
    type stack_array is array(0 to 7) of std_logic_vector(15 downto 0);
    signal stack : stack_array := (others => (others => '0'));
    signal stack_ptr : unsigned(2 downto 0) := (others => '0');
    signal return_address : std_logic_vector(15 downto 0) := (others => '0');

    -- Program counter and instruction
    signal pc : std_logic_vector(15 downto 0) := (others => '0');
    signal instruction : std_logic_vector(7 downto 0) := (others => '0');
    signal arg : std_logic_vector(15 downto 0) := (others => '0');

    -- Flags
    signal flag_zero : std_logic := '0';
    signal flag_carry : std_logic := '0';
    signal flag_sign : std_logic := '0';
    signal flag_parity : std_logic := '0';

    -- State machine
    type state_type is (
        STATE_RESET,
        STATE_FETCH_OP_0, STATE_FETCH_OP_1,
        STATE_START,
        STATE_FETCH_LO_0, STATE_FETCH_LO_1,
        STATE_FETCH_HI_0, STATE_FETCH_HI_1,
        STATE_FETCH_IM_0, STATE_FETCH_IM_1,
        STATE_FETCH_SOURCE,
        STATE_EXECUTE,
        STATE_EXECUTE_WB, STATE_EXECUTE_RD,
        STATE_FINISH_INC, STATE_FINISH_ALU, STATE_FINISH_SHIFT,
        STATE_FINISH_CALL,
        STATE_HALTED,
        STATE_ERROR
    );
    signal state : state_type := STATE_RESET;

    -- Timing state machine (real 8008 bus cycles)
    type timing_state_type is (T1, T1I, T2, TWAIT, T3, T4, T5);
    signal timing_state : timing_state_type := T1;

    -- Processor state for S2/S1/S0 encoding
    type proc_state_type is (
        PS_T1,      -- 000
        PS_T1I,     -- 001
        PS_T2,      -- 010
        PS_WAIT,    -- 011
        PS_T3,      -- 100
        PS_STOPPED, -- 101
        PS_T4,      -- 110
        PS_T5       -- 111
    );
    signal proc_state : proc_state_type := PS_T1;

    -- Cycle type (encoded on D7:D6 during T2)
    type cycle_type_t is (PCI, PCR, PCC, PCW);
    signal cycle_type : cycle_type_t := PCI;

    -- Bus control
    signal bus_address : std_logic_vector(13 downto 0) := (others => '0');
    signal bus_data_out : std_logic_vector(7 downto 0) := (others => '0');
    signal bus_data_in : std_logic_vector(7 downto 0);
    signal bus_drive : std_logic := '0';  -- '1' = CPU drives bus

    -- Memory transaction control
    signal mem_cycle_active : std_logic := '0';
    signal mem_is_write : std_logic := '0';
    signal mem_is_instruction_fetch : std_logic := '1';  -- Flag set by execution SM (init to '1' for first fetch)
    signal mem_cycle_done : std_logic := '0';  -- Set by timing SM when T3 completes

    -- Lower 6 bits of instruction (opcode)
    signal opcode : std_logic_vector(5 downto 0);

    -- Internal memory transaction signals (used by execution state machine)
    signal mem_address_int : std_logic_vector(15 downto 0) := (others => '0');
    signal mem_read_req : std_logic := '1';   -- Request memory read (init to '1' for first fetch)
    signal mem_write_req : std_logic := '0';  -- Request memory write
    signal mem_data_from_bus : std_logic_vector(7 downto 0);
    signal mem_data_to_bus : std_logic_vector(7 downto 0) := (others => '0');
    signal data_sample_enable : std_logic := '0';  -- Set during T3 to enable phi2 sampling

    -- Opcode constants
    constant OP_DCR : std_logic_vector(5 downto 0) := "000001";
    constant OP_INR : std_logic_vector(5 downto 0) := "000000";
    constant OP_MVI : std_logic_vector(5 downto 0) := "000110";
    constant OP_HLT_0 : std_logic_vector(5 downto 0) := "000000";
    constant OP_JMP : std_logic_vector(5 downto 0) := "000100";
    constant OP_MOV : std_logic_vector(5 downto 0) := "000000";
    constant OP_HLT_1 : std_logic_vector(5 downto 0) := "111111";

    -- ALU operation codes
    constant OP_ADD : std_logic_vector(2 downto 0) := "000";
    constant OP_ADC : std_logic_vector(2 downto 0) := "001";
    constant OP_SUB : std_logic_vector(2 downto 0) := "010";
    constant OP_SBB : std_logic_vector(2 downto 0) := "011";
    constant OP_ANA : std_logic_vector(2 downto 0) := "100";
    constant OP_XRA : std_logic_vector(2 downto 0) := "101";
    constant OP_ORA : std_logic_vector(2 downto 0) := "110";
    constant OP_CMP : std_logic_vector(2 downto 0) := "111";

    -- Conditional operation codes
    constant OP_JNC : std_logic_vector(2 downto 0) := "000";
    constant OP_JNZ : std_logic_vector(2 downto 0) := "001";
    constant OP_JP  : std_logic_vector(2 downto 0) := "010";
    constant OP_JPO : std_logic_vector(2 downto 0) := "011";
    constant OP_JC  : std_logic_vector(2 downto 0) := "100";
    constant OP_JZ  : std_logic_vector(2 downto 0) := "101";
    constant OP_JM  : std_logic_vector(2 downto 0) := "110";
    constant OP_JPE : std_logic_vector(2 downto 0) := "111";

begin
    -- HL register pair
    register_hl <= registers(5) & registers(6);

    -- Opcode extraction
    opcode <= instruction(5 downto 0);

    -- Halted status
    halted <= '1' when state = STATE_HALTED else '0';

    -- Debug outputs
    debug_reg_h <= registers(5);
    debug_reg_l <= registers(6);

    --===========================================
    -- S0/S1/S2 State Encoding (per 8008 datasheet)
    --===========================================
    process(proc_state)
    begin
        case proc_state is
            when PS_T1      => S2 <= '0'; S1 <= '0'; S0 <= '0';  -- 000
            when PS_T1I     => S2 <= '0'; S1 <= '0'; S0 <= '1';  -- 001
            when PS_T2      => S2 <= '0'; S1 <= '1'; S0 <= '0';  -- 010
            when PS_WAIT    => S2 <= '0'; S1 <= '1'; S0 <= '1';  -- 011
            when PS_T3      => S2 <= '1'; S1 <= '0'; S0 <= '0';  -- 100
            when PS_STOPPED => S2 <= '1'; S1 <= '0'; S0 <= '1';  -- 101
            when PS_T4      => S2 <= '1'; S1 <= '1'; S0 <= '0';  -- 110
            when PS_T5      => S2 <= '1'; S1 <= '1'; S0 <= '1';  -- 111
        end case;
    end process;

    -- SYNC is high during T1 and T1I
    SYNC <= '1' when (timing_state = T1 or timing_state = T1I) else '0';

    --===========================================
    -- Bus Multiplexing (Address/Data)
    --===========================================
    -- CPU drives the bus during T1, T2, and T3 (writes only)
    -- External logic drives during T3 (reads)

    process(timing_state, mem_address_int, cycle_type, bus_data_out)
        variable cycle_bits : std_logic_vector(1 downto 0);
        variable bus_output : std_logic_vector(7 downto 0);
        variable bus_drive_var : std_logic;
    begin
        -- Encode cycle type
        case cycle_type is
            when PCI => cycle_bits := "00";  -- Instruction fetch
            when PCR => cycle_bits := "01";  -- Memory read
            when PCC => cycle_bits := "10";  -- Memory write
            when PCW => cycle_bits := "11";  -- I/O (unused)
        end case;

        -- Default values
        bus_drive_var := '0';
        bus_output := (others => '0');

        case timing_state is
            when T1 | T1I =>
                -- T1: Lower 8 bits of address on bus
                -- Drive mem_address_int directly - real 8008 drives current address immediately
                bus_drive_var := '1';
                bus_output := mem_address_int(7 downto 0);
                report "Bus driver T1: Driving addr_low=0x" & to_hstring(mem_address_int(7 downto 0)) & " onto data_bus";

            when T2 =>
                -- T2: Upper 6 bits of address + cycle type on D7:D6
                -- Drive mem_address_int directly - real 8008 drives current address immediately
                bus_drive_var := '1';
                bus_output(5 downto 0) := mem_address_int(13 downto 8);
                bus_output(7 downto 6) := cycle_bits;
                report "Bus driver T2: Driving addr_high=0x" & to_hstring(mem_address_int(13 downto 8)) & " cycle=" & to_string(cycle_bits) & " onto data_bus";

            when T3 =>
                -- T3: Data transfer
                if cycle_type = PCC then
                    -- Write: CPU drives data
                    bus_drive_var := '1';
                    bus_output := bus_data_out;
                else
                    -- Read: CPU reads (tristate bus)
                    bus_drive_var := '0';
                end if;

            when others =>
                -- T4, T5, TWAIT: Tristate
                bus_drive_var := '0';
        end case;

        -- Drive bus when bus_drive_var is high
        if bus_drive_var = '1' then
            data_bus <= bus_output;
        else
            data_bus <= (others => 'Z');
        end if;

        -- Update signal for external visibility
        bus_drive <= bus_drive_var;
    end process;

    -- Capture data from bus during read cycles
    bus_data_in <= data_bus;

    -- ALU instantiation
    alu_inst : i8008_alu
        port map(
            data_0 => alu_data_0,
            data_1 => alu_data_1,
            flag_carry => flag_carry,
            command => alu_command,
            alu_result => alu_result
        );

    --===========================================
    -- Timing State Machine (T1/T2/T3/T4/T5 cycles)
    --===========================================
    -- This implements the real 8008's bus timing cycles
    -- Each memory access requires a full T1-T2-T3 sequence

    process(phi1, reset_n)
    begin
        if reset_n = '0' then
            timing_state <= T1;
            proc_state <= PS_T1;
            mem_cycle_active <= '0';
            mem_is_write <= '0';
            bus_address <= (others => '0');
            bus_data_out <= (others => '0');
            data_sample_enable <= '0';

        elsif rising_edge(phi1) then
            -- Update processor state for S0/S1/S2 encoding
            case timing_state is
                when T1    => proc_state <= PS_T1;
                when T1I   => proc_state <= PS_T1I;
                when T2    => proc_state <= PS_T2;
                when TWAIT => proc_state <= PS_WAIT;
                when T3    => proc_state <= PS_T3;
                when T4    => proc_state <= PS_T4;
                when T5    => proc_state <= PS_T5;
            end case;

            -- Timing state transitions
            case timing_state is
                when T1 =>
                    -- Always capture request state in T1, even if no request yet
                    mem_cycle_active <= mem_read_req or mem_write_req;
                    bus_address <= mem_address_int(13 downto 0);
                    mem_is_write <= mem_write_req;
                    report "T1: Loaded bus_address=0x" & to_hstring(mem_address_int(13 downto 0)) & " from mem_address_int";

                    -- Determine cycle type
                    if mem_write_req = '1' then
                        cycle_type <= PCC;  -- Memory write
                        bus_data_out <= mem_data_to_bus;
                        report "T1: Write request detected";
                    elsif mem_read_req = '1' then
                        if mem_is_instruction_fetch = '1' then
                            cycle_type <= PCI;  -- Instruction fetch
                            report "T1: Instruction fetch request detected";
                        else
                            cycle_type <= PCR;  -- Memory read
                            report "T1: Read request detected";
                        end if;
                    else
                        report "T1: No memory request (idle cycle)";
                    end if;

                    -- Always transition to T2 (or T1I for interrupts)
                    if INT = '1' then
                        timing_state <= T1I;
                    else
                        timing_state <= T2;
                    end if;

                when T1I =>
                    timing_state <= T2;

                when T2 =>
                    -- Check READY signal
                    if READY = '1' then
                        timing_state <= T3;
                    else
                        timing_state <= TWAIT;  -- Insert wait states
                    end if;

                when TWAIT =>
                    -- Stay in wait until READY
                    if READY = '1' then
                        timing_state <= T3;
                    end if;

                when T3 =>
                    -- Data transfer state - enable sampling on phi2 for read cycles
                    if mem_cycle_active = '1' and cycle_type /= PCC then
                        -- Active read cycle: enable data sampling
                        data_sample_enable <= '1';
                        report "T3: Enabled data sampling";
                    elsif mem_cycle_active = '1' then
                        report "T3: Write cycle, no sampling";
                    else
                        report "T3: Idle cycle, no transfer";
                    end if;
                    mem_cycle_active <= '0';
                    timing_state <= T4;

                when T4 =>
                    data_sample_enable <= '0';  -- Clear sample enable
                    timing_state <= T5;

                when T5 =>
                    -- Return to T1 only if there's a pending memory request
                    -- This prevents spurious idle cycles that can sample stale data
                    if state = STATE_HALTED then
                        proc_state <= PS_STOPPED;
                        -- Stay in T5 when halted
                    elsif mem_read_req = '1' or mem_write_req = '1' then
                        timing_state <= T1;
                    else
                        -- No pending request, stay in T5 (idle)
                        null;
                    end if;
            end case;
        end if;
    end process;

    --===========================================
    -- Data Bus Sampling and Cycle Completion (on phi2)
    --===========================================
    -- The real 8008 samples data on phi2, not phi1
    -- This ensures the bus has stabilized after external logic responds to S0/S1/S2
    -- Also signals cycle completion to the execution SM (which runs on phi2)
    process(phi2, reset_n)
        variable cycle_was_active : std_logic := '0';
    begin
        if reset_n = '0' then
            mem_data_from_bus <= (others => '0');
            mem_cycle_done <= '0';
            cycle_was_active := '0';
        elsif rising_edge(phi2) then
            -- Sample data during T3
            if data_sample_enable = '1' then
                mem_data_from_bus <= bus_data_in;
                report "CPU sampled data from bus: 0x" & to_hstring(bus_data_in);
            end if;

            -- Track whether a cycle was active during T3 (before it's cleared)
            if timing_state = T3 and mem_cycle_active = '1' then
                cycle_was_active := '1';
            end if;

            -- Signal completion at T4 (on phi2) if a cycle was active
            if timing_state = T4 and cycle_was_active = '1' then
                mem_cycle_done <= '1';
                cycle_was_active := '0';  -- Clear for next cycle
                report "Signaling cycle complete on phi2 during T4";
            -- Clear when both requests are low (execution SM acknowledged)
            elsif mem_read_req = '0' and mem_write_req = '0' then
                mem_cycle_done <= '0';
            end if;
        end if;
    end process;

    --===========================================
    -- Main CPU state machine
    --===========================================
    -- This runs the instruction execution logic
    -- It requests memory cycles via mem_read_req/mem_write_req
    -- and waits for timing_state to complete the bus cycle

    process(phi2)
        variable parity_calc : std_logic;
    begin
        if rising_edge(phi2) then
            if reset_n = '0' then
                state <= STATE_RESET;
            else
                case state is
                    when STATE_RESET =>
                        stack_ptr <= (others => '0');
                        flag_zero <= '0';
                        flag_carry <= '0';
                        flag_sign <= '0';
                        flag_parity <= '0';
                        mem_address_int <= (others => '0');
                        mem_data_to_bus <= (others => '0');
                        instruction <= (others => '0');
                        pc <= (others => '0');
                        -- Don't clear mem_read_req/mem_is_instruction_fetch - keep initial values
                        -- so first instruction fetch happens immediately
                        state <= STATE_FETCH_OP_0;

                    when STATE_FETCH_OP_0 =>
                        -- Request memory read for instruction fetch
                        mem_read_req <= '1';
                        mem_is_instruction_fetch <= '1';  -- Mark as instruction fetch
                        mem_address_int <= pc;
                        mem_write_req <= '0';
                        report "Execution SM: Requesting instruction fetch from PC=" & to_hstring(pc);
                        state <= STATE_FETCH_OP_1;

                    when STATE_FETCH_OP_1 =>
                        -- Wait for timing state to complete bus cycle
                        if mem_cycle_done = '1' then
                            mem_read_req <= '0';
                            mem_is_instruction_fetch <= '0';  -- Clear flag
                            instruction <= mem_data_from_bus;
                            report "Instruction fetched: 0x" & to_hstring(mem_data_from_bus);
                            state <= STATE_START;
                            pc <= std_logic_vector(unsigned(pc) + 1);
                        end if;

                    when STATE_START =>
                        report "STATE_START: instruction=0x" & to_hstring(instruction) & " opcode[2:0]=" & to_string(opcode(2 downto 0));
                        case instruction(7 downto 6) is
                            when "00" =>
                                -- Immediate instructions, inc, dec, halt
                                if opcode(2 downto 0) = "000" then
                                    if opcode(5 downto 3) = "000" then
                                        state <= STATE_HALTED;
                                    else
                                        state <= STATE_EXECUTE;
                                    end if;
                                elsif opcode(2 downto 0) = "001" then
                                    if opcode(5 downto 3) = "000" then
                                        state <= STATE_HALTED;
                                    else
                                        state <= STATE_EXECUTE;
                                    end if;
                                elsif opcode(2 downto 0) = "010" then
                                    -- Shift: RLC, RRC, RAL, RAR
                                    state <= STATE_EXECUTE;
                                elsif opcode(2 downto 0) = "011" then
                                    -- Return (conditional) - adjust stack
                                    case opcode(5 downto 3) is
                                        when OP_JNC => if flag_carry = '0' then stack_ptr <= stack_ptr - 1; end if;
                                        when OP_JNZ => if flag_zero = '0' then stack_ptr <= stack_ptr - 1; end if;
                                        when OP_JP  => if flag_sign = '0' then stack_ptr <= stack_ptr - 1; end if;
                                        when OP_JPO => if flag_parity = '1' then stack_ptr <= stack_ptr - 1; end if;
                                        when OP_JC  => if flag_carry = '1' then stack_ptr <= stack_ptr - 1; end if;
                                        when OP_JZ  => if flag_zero = '1' then stack_ptr <= stack_ptr - 1; end if;
                                        when OP_JM  => if flag_sign = '1' then stack_ptr <= stack_ptr - 1; end if;
                                        when OP_JPE => if flag_parity = '0' then stack_ptr <= stack_ptr - 1; end if;
                                        when others => null;
                                    end case;
                                    state <= STATE_EXECUTE;
                                elsif opcode(2 downto 0) = "100" then
                                    -- ALU with immediate
                                    state <= STATE_FETCH_IM_0;
                                elsif opcode(2 downto 0) = "101" then
                                    -- RST
                                    return_address <= std_logic_vector(unsigned(pc) + 2);
                                    state <= STATE_EXECUTE;
                                elsif opcode(2 downto 0) = "110" then
                                    -- MVI with immediate
                                    report "MVI detected, transitioning to STATE_FETCH_IM_0";
                                    state <= STATE_FETCH_IM_0;
                                elsif opcode(2 downto 0) = "111" then
                                    -- Return
                                    stack_ptr <= stack_ptr - 1;
                                    state <= STATE_EXECUTE;
                                else
                                    state <= STATE_ERROR;
                                end if;

                            when "01" =>
                                if opcode(0) = '1' then
                                    -- IN/OUT instructions (skip for clean core)
                                    state <= STATE_EXECUTE;
                                else
                                    if opcode(2 downto 0) = "010" or opcode(2 downto 0) = "110" then
                                        -- Call
                                        return_address <= std_logic_vector(unsigned(pc) + 2);
                                    end if;
                                    -- Jump and call instructions
                                    state <= STATE_FETCH_LO_0;
                                end if;

                            when "10" =>
                                -- ALU with registers
                                if opcode(2 downto 0) = "111" then
                                    mem_address_int <= register_hl;
                                    mem_write_req <= '0';
                                end if;
                                state <= STATE_EXECUTE;

                            when "11" =>
                                -- MOV instructions or halt
                                if opcode = OP_HLT_1 then
                                    state <= STATE_HALTED;
                                else
                                    state <= STATE_EXECUTE;
                                end if;

                            when others =>
                                state <= STATE_ERROR;
                        end case;

                    when STATE_FETCH_LO_0 =>
                        mem_read_req <= '1';
                        mem_address_int <= pc;
                        mem_write_req <= '0';
                        state <= STATE_FETCH_LO_1;

                    when STATE_FETCH_LO_1 =>
                        if mem_cycle_done = '1' then
                            mem_read_req <= '0';
                            arg(7 downto 0) <= mem_data_from_bus;
                            state <= STATE_FETCH_HI_0;
                            pc <= std_logic_vector(unsigned(pc) + 1);
                        end if;

                    when STATE_FETCH_HI_0 =>
                        mem_read_req <= '1';
                        mem_address_int <= pc;
                        mem_write_req <= '0';
                        state <= STATE_FETCH_HI_1;

                    when STATE_FETCH_HI_1 =>
                        if mem_cycle_done = '1' then
                            mem_read_req <= '0';
                            arg(15 downto 8) <= mem_data_from_bus;
                            state <= STATE_EXECUTE;
                            pc <= std_logic_vector(unsigned(pc) + 1);
                        end if;

                    when STATE_FETCH_IM_0 =>
                        report "STATE_FETCH_IM_0: Requesting immediate byte from PC=" & to_hstring(pc);
                        mem_read_req <= '1';
                        mem_address_int <= pc;
                        mem_write_req <= '0';
                        state <= STATE_FETCH_IM_1;

                    when STATE_FETCH_IM_1 =>
                        if mem_cycle_done = '1' then
                            mem_read_req <= '0';
                            report "Immediate byte fetched: 0x" & to_hstring(mem_data_from_bus);
                            arg(15 downto 8) <= (others => '0');
                            arg(7 downto 0) <= mem_data_from_bus;
                            state <= STATE_EXECUTE;
                            pc <= std_logic_vector(unsigned(pc) + 1);
                        end if;

                    when STATE_EXECUTE =>
                        case instruction(7 downto 6) is
                            when "00" =>
                                if opcode(2 downto 0) = "000" then
                                    -- INR
                                    inc_result <= std_logic_vector(unsigned(registers(to_integer(unsigned(opcode(5 downto 3))))) + 1);
                                    state <= STATE_FINISH_INC;
                                elsif opcode(2 downto 0) = "001" then
                                    -- DCR
                                    inc_result <= std_logic_vector(unsigned(registers(to_integer(unsigned(opcode(5 downto 3))))) - 1);
                                    state <= STATE_FINISH_INC;
                                elsif opcode(2 downto 0) = "010" then
                                    -- Rotate instructions
                                    case opcode(5 downto 3) is
                                        when "000" =>  -- RLC
                                            shift_result(7 downto 1) <= registers(0)(6 downto 0);
                                            shift_result(0) <= registers(0)(7);
                                            shift_carry <= registers(0)(7);
                                            state <= STATE_FINISH_SHIFT;
                                        when "001" =>  -- RRC
                                            shift_result(6 downto 0) <= registers(0)(7 downto 1);
                                            shift_result(7) <= registers(0)(0);
                                            shift_carry <= registers(0)(0);
                                            state <= STATE_FINISH_SHIFT;
                                        when "010" =>  -- RAL
                                            shift_result(7 downto 1) <= registers(0)(6 downto 0);
                                            shift_result(0) <= flag_carry;
                                            shift_carry <= registers(0)(7);
                                            state <= STATE_FINISH_SHIFT;
                                        when "011" =>  -- RAR
                                            shift_result(6 downto 0) <= registers(0)(7 downto 1);
                                            shift_result(7) <= flag_carry;
                                            shift_carry <= registers(0)(0);
                                            state <= STATE_FINISH_SHIFT;
                                        when others =>
                                            state <= STATE_ERROR;
                                    end case;
                                elsif opcode(2 downto 0) = "011" then
                                    -- Return (conditional)
                                    case opcode(5 downto 3) is
                                        when OP_JNC => if flag_carry = '0' then pc <= stack(to_integer(stack_ptr)); end if;
                                        when OP_JNZ => if flag_zero = '0' then pc <= stack(to_integer(stack_ptr)); end if;
                                        when OP_JP  => if flag_sign = '0' then pc <= stack(to_integer(stack_ptr)); end if;
                                        when OP_JPO => if flag_parity = '1' then pc <= stack(to_integer(stack_ptr)); end if;
                                        when OP_JC  => if flag_carry = '1' then pc <= stack(to_integer(stack_ptr)); end if;
                                        when OP_JZ  => if flag_zero = '1' then pc <= stack(to_integer(stack_ptr)); end if;
                                        when OP_JM  => if flag_sign = '1' then pc <= stack(to_integer(stack_ptr)); end if;
                                        when OP_JPE => if flag_parity = '0' then pc <= stack(to_integer(stack_ptr)); end if;
                                        when others => null;
                                    end case;
                                    state <= STATE_FETCH_OP_0;
                                elsif opcode(2 downto 0) = "100" then
                                    -- ALU with immediate
                                    alu_data_0 <= registers(0);
                                    alu_data_1 <= arg(7 downto 0);
                                    alu_command <= opcode(5 downto 3);
                                    state <= STATE_FINISH_ALU;
                                elsif opcode(2 downto 0) = "101" then
                                    -- RST
                                    pc(2 downto 0) <= opcode(5 downto 3);
                                    pc(15 downto 3) <= (others => '0');
                                    stack(to_integer(stack_ptr)) <= return_address;
                                    state <= STATE_FINISH_CALL;
                                elsif opcode(2 downto 0) = "110" then
                                    -- MVI
                                    if opcode(5 downto 3) = "111" then
                                        mem_address_int <= register_hl;
                                        mem_data_to_bus <= arg(7 downto 0);
                                        mem_write_req <= '1';
                                        state <= STATE_EXECUTE_WB;
                                    else
                                        registers(to_integer(unsigned(opcode(5 downto 3)))) <= arg(7 downto 0);
                                        state <= STATE_FETCH_OP_0;
                                    end if;
                                elsif opcode(2 downto 0) = "111" then
                                    -- Return
                                    pc <= stack(to_integer(stack_ptr));
                                    state <= STATE_FETCH_OP_0;
                                end if;

                            when "01" =>
                                if opcode(0) = '1' then
                                    -- IN/OUT (skip for clean core)
                                    state <= STATE_FETCH_OP_0;
                                else
                                    if opcode(2 downto 0) = "100" then
                                        -- JMP
                                        pc <= arg;
                                        state <= STATE_FETCH_OP_0;
                                    elsif opcode(2 downto 0) = "110" then
                                        -- Call
                                        pc <= arg;
                                        stack(to_integer(stack_ptr)) <= return_address;
                                        state <= STATE_FINISH_CALL;
                                    elsif opcode(2 downto 0) = "000" then
                                        -- Jump (conditional)
                                        case opcode(5 downto 3) is
                                            when OP_JNC => if flag_carry = '0' then pc <= arg; end if;
                                            when OP_JNZ => if flag_zero = '0' then pc <= arg; end if;
                                            when OP_JP  => if flag_sign = '0' then pc <= arg; end if;
                                            when OP_JPO => if flag_parity = '1' then pc <= arg; end if;
                                            when OP_JC  => if flag_carry = '1' then pc <= arg; end if;
                                            when OP_JZ  => if flag_zero = '1' then pc <= arg; end if;
                                            when OP_JM  => if flag_sign = '1' then pc <= arg; end if;
                                            when OP_JPE => if flag_parity = '0' then pc <= arg; end if;
                                            when others => null;
                                        end case;
                                        state <= STATE_FETCH_OP_0;
                                    elsif opcode(2 downto 0) = "010" then
                                        -- Call (conditional)
                                        case opcode(5 downto 3) is
                                            when OP_JNC => if flag_carry = '0' then pc <= arg; end if;
                                            when OP_JNZ => if flag_zero = '0' then pc <= arg; end if;
                                            when OP_JP  => if flag_sign = '0' then pc <= arg; end if;
                                            when OP_JPO => if flag_parity = '1' then pc <= arg; end if;
                                            when OP_JC  => if flag_carry = '1' then pc <= arg; end if;
                                            when OP_JZ  => if flag_zero = '1' then pc <= arg; end if;
                                            when OP_JM  => if flag_sign = '1' then pc <= arg; end if;
                                            when OP_JPE => if flag_parity = '0' then pc <= arg; end if;
                                            when others => null;
                                        end case;
                                        stack(to_integer(stack_ptr)) <= return_address;
                                        state <= STATE_FINISH_CALL;
                                    else
                                        state <= STATE_ERROR;
                                    end if;
                                end if;

                            when "10" =>
                                -- ALU with registers
                                if opcode(2 downto 0) = "111" then
                                    alu_data_1 <= mem_data_from_bus;
                                else
                                    alu_data_1 <= registers(to_integer(unsigned(opcode(2 downto 0))));
                                end if;
                                alu_data_0 <= registers(0);
                                alu_command <= opcode(5 downto 3);
                                state <= STATE_FINISH_ALU;

                            when "11" =>
                                -- MOV
                                if opcode(5 downto 3) = "111" then
                                    mem_address_int <= register_hl;
                                    mem_data_to_bus <= registers(to_integer(unsigned(opcode(2 downto 0))));
                                    mem_write_req <= '1';
                                    state <= STATE_EXECUTE_WB;
                                elsif opcode(2 downto 0) = "111" then
                                    mem_address_int <= register_hl;
                                    mem_read_req <= '1';
                                    state <= STATE_EXECUTE_RD;
                                else
                                    registers(to_integer(unsigned(opcode(5 downto 3)))) <=
                                        registers(to_integer(unsigned(opcode(2 downto 0))));
                                    state <= STATE_FETCH_OP_0;
                                end if;

                            when others =>
                                state <= STATE_ERROR;
                        end case;

                    when STATE_EXECUTE_WB =>
                        if mem_cycle_done = '1' then
                            mem_write_req <= '0';
                            state <= STATE_FETCH_OP_0;
                        end if;

                    when STATE_EXECUTE_RD =>
                        if mem_cycle_done = '1' then
                            mem_read_req <= '0';
                            registers(to_integer(unsigned(opcode(5 downto 3)))) <= mem_data_from_bus;
                            state <= STATE_FETCH_OP_0;
                        end if;

                    when STATE_FINISH_INC =>
                        registers(to_integer(unsigned(opcode(5 downto 3)))) <= inc_result;
                        flag_zero <= '1' when inc_result = x"00" else '0';
                        flag_sign <= inc_result(7);
                        parity_calc := inc_result(7) xor inc_result(6) xor inc_result(5) xor inc_result(4) xor
                                       inc_result(3) xor inc_result(2) xor inc_result(1) xor inc_result(0) xor '1';
                        flag_parity <= parity_calc;
                        state <= STATE_FETCH_OP_0;

                    when STATE_FINISH_ALU =>
                        if opcode(5 downto 3) /= "111" then
                            registers(0) <= alu_result(7 downto 0);
                        end if;
                        flag_zero <= '1' when alu_result(7 downto 0) = x"00" else '0';
                        flag_carry <= alu_result(8);
                        flag_sign <= alu_result(7);
                        parity_calc := alu_result(7) xor alu_result(6) xor alu_result(5) xor alu_result(4) xor
                                       alu_result(3) xor alu_result(2) xor alu_result(1) xor alu_result(0) xor '1';
                        flag_parity <= parity_calc;
                        state <= STATE_FETCH_OP_0;

                    when STATE_FINISH_SHIFT =>
                        registers(0) <= shift_result;
                        flag_carry <= shift_carry;
                        state <= STATE_FETCH_OP_0;

                    when STATE_FINISH_CALL =>
                        stack_ptr <= stack_ptr + 1;
                        state <= STATE_FETCH_OP_0;

                    when STATE_HALTED =>
                        mem_write_req <= '0';
                        mem_read_req <= '0';
                        state <= STATE_HALTED;

                    when STATE_ERROR =>
                        mem_write_req <= '0';
                        mem_read_req <= '0';
                        state <= STATE_ERROR;

                    when others =>
                        state <= STATE_ERROR;
                end case;
            end if;
        end if;
    end process;

end rtl;
