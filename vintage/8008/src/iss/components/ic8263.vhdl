-------------------------------------------------------------------------------
-- Signetics 8263 Quad Bus Transceiver - VHDL Recreation
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Robert Rico
-- Based on Signetics 8263 datasheet specifications
-- License: MIT (see LICENSE.txt)
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ic8263 is
    port(
        -- A, B, C
        A : in std_logic_vector(3 downto 0);
        B : in std_logic_vector(3 downto 0);
        C : in std_logic_vector(3 downto 0);

        -- SEL
        SEL : in std_logic_vector(1 downto 0);

        -- OE
        OE : in std_logic_vector(2 downto 0);

        -- Data Complement
        D : in std_logic;

        -- Y
        Y : out std_logic_vector(3 downto 0)
    );
end ic8263;


architecture rtl of ic8263 is
    signal y_out : std_logic_vector(3 downto 0) := "0000";

begin
    process(A,B,C,SEL,OE,D)
    begin
        if OE(0) = '0' or OE(1) = '0' or OE(2) = '0' then
            y_out <= "1111";
        else 
            case SEL is
                when "00" => 
                    if D = '1' then
                        y_out <= "1111";
                    else
                        y_out <= "0000";
                    end if;
                when "01" => 
                    -- B
                    if D = '1' then
                        y_out <= not B;
                    else
                        y_out <= B;
                    end if;
                when "10" => 
                    -- C
                    if D = '1' then
                        y_out <= not C;
                    else
                        y_out <= C;
                    end if;
                when "11" => 
                    if D = '1' then
                        y_out <= not A;
                    else
                        y_out <= A;
                    end if;
                when others => 
                    y_out <= "0000";
            end case;
        end if;
    end process;

    Y <= y_out;

end rtl;