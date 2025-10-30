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

    -- Initialize ROM with some test data (replace with actual program later)
    signal rom : rom_array := (
        0 => x"00",  -- Example: NOP or your program
        1 => x"01",
        2 => x"02",
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
