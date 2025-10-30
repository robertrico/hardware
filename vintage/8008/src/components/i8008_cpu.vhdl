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
        clk : in std_logic;
        reset_n : in std_logic;

        -- Memory bus
        mem_address : out std_logic_vector(13 downto 0);  -- 14-bit address (16KB)
        mem_data_in : out std_logic_vector(7 downto 0);
        mem_data_out : in std_logic_vector(7 downto 0);
        mem_read : out std_logic;
        mem_write : out std_logic;

        -- Status outputs
        halted : out std_logic
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

    -- Lower 6 bits of instruction (opcode)
    signal opcode : std_logic_vector(5 downto 0);

    -- Internal memory control signals
    signal mem_address_int : std_logic_vector(15 downto 0) := (others => '0');
    signal mem_read_int : std_logic := '0';
    signal mem_write_int : std_logic := '0';

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

    -- Memory bus outputs (14-bit address)
    mem_address <= mem_address_int(13 downto 0);
    mem_read <= mem_read_int;
    mem_write <= mem_write_int;

    -- Halted status
    halted <= '1' when state = STATE_HALTED else '0';

    -- ALU instantiation
    alu_inst : i8008_alu
        port map(
            data_0 => alu_data_0,
            data_1 => alu_data_1,
            flag_carry => flag_carry,
            command => alu_command,
            alu_result => alu_result
        );

    -- Main CPU state machine
    process(clk)
        variable parity_calc : std_logic;
    begin
        if rising_edge(clk) then
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
                        mem_write_int <= '0';
                        mem_data_in <= (others => '0');
                        instruction <= (others => '0');
                        pc <= (others => '0');
                        state <= STATE_FETCH_OP_0;

                    when STATE_FETCH_OP_0 =>
                        mem_read_int <= '1';
                        mem_address_int <= pc;
                        mem_write_int <= '0';
                        state <= STATE_FETCH_OP_1;

                    when STATE_FETCH_OP_1 =>
                        mem_read_int <= '0';
                        instruction <= mem_data_out;
                        state <= STATE_START;
                        pc <= std_logic_vector(unsigned(pc) + 1);

                    when STATE_START =>
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
                                    mem_write_int <= '0';
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
                        mem_read_int <= '1';
                        mem_address_int <= pc;
                        mem_write_int <= '0';
                        state <= STATE_FETCH_LO_1;

                    when STATE_FETCH_LO_1 =>
                        mem_read_int <= '0';
                        arg(7 downto 0) <= mem_data_out;
                        state <= STATE_FETCH_HI_0;
                        pc <= std_logic_vector(unsigned(pc) + 1);

                    when STATE_FETCH_HI_0 =>
                        mem_read_int <= '1';
                        mem_address_int <= pc;
                        mem_write_int <= '0';
                        state <= STATE_FETCH_HI_1;

                    when STATE_FETCH_HI_1 =>
                        mem_read_int <= '0';
                        arg(15 downto 8) <= mem_data_out;
                        state <= STATE_EXECUTE;
                        pc <= std_logic_vector(unsigned(pc) + 1);

                    when STATE_FETCH_IM_0 =>
                        mem_read_int <= '1';
                        mem_address_int <= pc;
                        mem_write_int <= '0';
                        state <= STATE_FETCH_IM_1;

                    when STATE_FETCH_IM_1 =>
                        mem_read_int <= '0';
                        arg(15 downto 8) <= (others => '0');
                        arg(7 downto 0) <= mem_data_out;
                        state <= STATE_EXECUTE;
                        pc <= std_logic_vector(unsigned(pc) + 1);

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
                                        mem_data_in <= arg(7 downto 0);
                                        mem_write_int <= '1';
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
                                    alu_data_1 <= mem_data_out;
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
                                    mem_data_in <= registers(to_integer(unsigned(opcode(2 downto 0))));
                                    mem_write_int <= '1';
                                    state <= STATE_EXECUTE_WB;
                                elsif opcode(2 downto 0) = "111" then
                                    mem_address_int <= register_hl;
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
                        mem_read_int <= '1';
                        mem_write_int <= '0';
                        state <= STATE_FETCH_OP_0;

                    when STATE_EXECUTE_RD =>
                        mem_read_int <= '0';
                        registers(to_integer(unsigned(opcode(5 downto 3)))) <= mem_data_out;
                        state <= STATE_FETCH_OP_0;

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
                        mem_write_int <= '0';
                        state <= STATE_HALTED;

                    when STATE_ERROR =>
                        mem_write_int <= '0';
                        state <= STATE_ERROR;

                    when others =>
                        state <= STATE_ERROR;
                end case;
            end if;
        end if;
    end process;

end rtl;
