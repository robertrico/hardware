library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ram_1kx8 is
    port(
        -- 10-bit address (2^10 = 1024)
        ADDR : in std_logic_vector(9 downto 0);

        -- 8-bit bidirectional data
        DATA_IN : in std_logic_vector(7 downto 0);
        DATA_OUT : out std_logic_vector(7 downto 0);

        -- Read/Write control (active low)
        RW_N : in std_logic;  -- 0 = Write, 1 = Read

        -- Chip select (active low)
        CS_N : in std_logic
    );
end ram_1kx8;

architecture rtl of ram_1kx8 is
    -- RAM storage: 1024 locations x 8 bits
    type ram_array is array(0 to 1023) of std_logic_vector(7 downto 0);
    signal ram : ram_array := (others => x"00");  -- Initialize to zeros

begin
    process(ADDR, DATA_IN, RW_N, CS_N)
    begin
        if CS_N = '0' then
            -- Chip selected
            if RW_N = '0' then
                -- Write mode
                ram(to_integer(unsigned(ADDR))) <= DATA_IN;
            else
                -- Read mode
                DATA_OUT <= ram(to_integer(unsigned(ADDR)));
            end if;
        else
            -- Chip not selected, tri-state
            DATA_OUT <= (others => 'Z');
        end if;
    end process;

end rtl;
