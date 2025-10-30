-------------------------------------------------------------------------------
-- Intel 8008 ALU - VHDL Conversion
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Robert Rico (VHDL conversion)
-- Copyright (c) 2022-2024 Michael Kohn (original Verilog implementation)
--
-- This VHDL implementation is derived from Michael Kohn's i8008 Verilog
-- implementation. The ALU operations and flag handling follow Kohn's
-- original design.
--
-- Original Verilog: https://www.mikekohn.net/
-- License: MIT (see LICENSE.txt)
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i8008_alu is
    port(
        data_0 : in std_logic_vector(7 downto 0);
        data_1 : in std_logic_vector(7 downto 0);
        flag_carry : in std_logic;
        command : in std_logic_vector(2 downto 0);
        alu_result : out std_logic_vector(8 downto 0)
    );
end i8008_alu;

architecture rtl of i8008_alu is
    constant OP_ADD : std_logic_vector(2 downto 0) := "000";
    constant OP_ADC : std_logic_vector(2 downto 0) := "001";
    constant OP_SUB : std_logic_vector(2 downto 0) := "010";
    constant OP_SBB : std_logic_vector(2 downto 0) := "011";
    constant OP_ANA : std_logic_vector(2 downto 0) := "100";
    constant OP_XRA : std_logic_vector(2 downto 0) := "101";
    constant OP_ORA : std_logic_vector(2 downto 0) := "110";
    constant OP_CMP : std_logic_vector(2 downto 0) := "111";

    signal result : std_logic_vector(8 downto 0);

begin
    process(command, data_0, data_1, flag_carry)
        variable carry_val : unsigned(8 downto 0);
    begin
        carry_val := (others => '0');
        if flag_carry = '1' then
            carry_val(0) := '1';
        end if;

        case command is
            when OP_ADD =>
                result <= std_logic_vector(unsigned('0' & data_0) + unsigned('0' & data_1));
            when OP_ADC =>
                result <= std_logic_vector(unsigned('0' & data_0) + unsigned('0' & data_1) + carry_val);
            when OP_SUB =>
                result <= std_logic_vector(unsigned('0' & data_0) - unsigned('0' & data_1));
            when OP_SBB =>
                result <= std_logic_vector(unsigned('0' & data_0) - unsigned('0' & data_1) + carry_val);
            when OP_ANA =>
                result <= '0' & (data_0 and data_1);
            when OP_XRA =>
                result <= '0' & (data_0 xor data_1);
            when OP_ORA =>
                result <= '0' & (data_0 or data_1);
            when OP_CMP =>
                result <= std_logic_vector(unsigned('0' & data_0) - unsigned('0' & data_1));
            when others =>
                result <= (others => '0');
        end case;
    end process;

    alu_result <= result;

end rtl;
