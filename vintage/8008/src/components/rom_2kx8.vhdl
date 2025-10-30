-------------------------------------------------------------------------------
-- 2K x 8 ROM Memory Component
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Robert Rico
-- License: MIT (see LICENSE.txt)
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rom_2kx8 is
    port(
        -- 11-bit address (2^11 = 2048)
        ADDR : in std_logic_vector(10 downto 0);

        -- 8-bit data output
        DATA_OUT : out std_logic_vector(7 downto 0);

        -- Chip select (active low)
        CS_N : in std_logic
    );
end rom_2kx8;

architecture rtl of rom_2kx8 is
    -- ROM storage: 2048 locations x 8 bits
    type rom_array is array(0 to 2047) of std_logic_vector(7 downto 0);

    -- Initialize ROM with test program
    -- ADD test with RAM write: A = 5 + 3 = 8, store at RAM[0x0800]
    signal rom : rom_array := (
        0 => x"06",  -- MVI A, 5   (00_000_110)
        1 => x"05",  -- Immediate value 5
        2 => x"0E",  -- MVI B, 3   (00_001_110)
        3 => x"03",  -- Immediate value 3
        4 => x"81",  -- ADD B       (10_000_001) -> A = 8
        5 => x"2E",  -- MVI H, 0x08 (00_101_110) -> H = 0x08 (register 101)
        6 => x"08",  -- Immediate value 0x08
        7 => x"36",  -- MVI L, 0x00 (00_110_110) -> L = 0x00 (register 110)
        8 => x"00",  -- Immediate value 0x00
        9 => x"F8",  -- MOV M, A    (11_111_000) -> Write A to memory[H:L]
       10 => x"00",  -- HLT         (00_000_000)
        others => x"FF"  -- Fill rest with 0xFF
    );

begin
    process(ADDR, CS_N)
    begin
        if CS_N = '0' then
            -- Chip selected, output data
            DATA_OUT <= rom(to_integer(unsigned(ADDR)));
        else
            -- Chip not selected, tri-state (high-Z)
            DATA_OUT <= (others => 'Z');
        end if;
    end process;

end rtl;
