-------------------------------------------------------------------------------
-- 1K x 8 RAM Memory Component
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Robert Rico
-- License: MIT (see LICENSE.txt)
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ram_1kx8 is
    port(
        -- Clock for synchronous writes
        CLK : in std_logic;

        -- 10-bit address (2^10 = 1024)
        ADDR : in std_logic_vector(9 downto 0);

        -- 8-bit bidirectional data
        DATA_IN : in std_logic_vector(7 downto 0);
        DATA_OUT : out std_logic_vector(7 downto 0);

        -- Read/Write control (active low)
        RW_N : in std_logic;  -- 0 = Write, 1 = Read

        -- Chip select (active low)
        CS_N : in std_logic;

        -- Debug output for testbench - exposes location 0
        DEBUG_BYTE_0 : out std_logic_vector(7 downto 0)
    );
end ram_1kx8;

architecture rtl of ram_1kx8 is
    -- RAM storage: 1024 locations x 8 bits
    type ram_array is array(0 to 1023) of std_logic_vector(7 downto 0);
    signal ram : ram_array := (others => x"00");  -- Initialize to zeros

begin
    -- Synchronous write process
    write_proc: process(CLK)
    begin
        if rising_edge(CLK) then
            if CS_N = '0' and RW_N = '0' then
                -- Write mode: store data on clock edge
                ram(to_integer(unsigned(ADDR))) <= DATA_IN;
            end if;
        end if;
    end process;

    -- Combinational read process
    read_proc: process(ADDR, CS_N, ram)
    begin
        if CS_N = '0' and RW_N = '1' then
            -- Read mode: output data combinationally
            DATA_OUT <= ram(to_integer(unsigned(ADDR)));
        else
            -- Not selected or writing, tri-state
            DATA_OUT <= (others => 'Z');
        end if;
    end process;

    -- Debug output - always expose location 0
    DEBUG_BYTE_0 <= ram(0);

end rtl;
