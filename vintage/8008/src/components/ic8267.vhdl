-------------------------------------------------------------------------------
-- Signetics 8267 Quad 2-Input Multiplexer - VHDL Recreation
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Robert Rico
-- Based on Signetics 8267 datasheet specifications
-- License: MIT (see LICENSE.txt)
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ic8267 is
    port(
        -- A, B inputs (4-bit each)
        A : in std_logic_vector(3 downto 0);
        B : in std_logic_vector(3 downto 0);

        -- Dual select lines (must both match for selection)
        S0 : in std_logic;
        S1 : in std_logic;

        -- Output
        Y : out std_logic_vector(3 downto 0)
    );
end ic8267;

architecture rtl of ic8267 is
    signal y_out : std_logic_vector(3 downto 0);
begin
    process(A,B,S0,S1)
    begin
        if S0 = '1' and S1 = '1' then
            y_out <= "1111";
        elsif S0 = '1' and S1 = '0' then
            y_out <= not A;
        else
            y_out <= B;
        end if;
    end process;

    Y <= y_out;
end rtl;
