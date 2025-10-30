library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ic3404 is
    port(
        -- 6-bit data inputs
        D : in std_logic_vector(5 downto 0);

        -- Write enable for 4-bit section (D0-D3)
        W1 : in std_logic;

        -- Write enable for 2-bit section (D4-D5)
        W2 : in std_logic;

        -- 6-bit data outputs
        O : out std_logic_vector(5 downto 0)
    );
end ic3404;


architecture rtl of ic3404 is
    signal data_out : std_logic_vector(5 downto 0) := "000000";
begin
    process(D, W1, W2)
    begin
        if W1 = '1' then
            data_out(3 downto 0) <= D(3 downto 0);
        end if;
        if W2 = '1' then
            data_out(4) <= D(4);
            data_out(5) <= D(5);
        end if;
    end process;

    O <= data_out;

end rtl;
