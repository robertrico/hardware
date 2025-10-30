library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ic3205 is
    port(
        -- 3-bit address input
        A : in std_logic_vector(2 downto 0);

        -- 3 enable inputs (all must be correct for outputs to activate)
        E1 : in std_logic;
        E2 : in std_logic;
        E3 : in std_logic;

        -- 8 outputs (one-hot decoded)
        O : out std_logic_vector(7 downto 0)
    );
end ic3205;


architecture rtl of ic3205 is
    signal data_out : std_logic_vector(7 downto 0) := (others => '1');
begin
    -- Implement logic below
    process(A, E1, E2, E3)
    begin
        if E1 = '0' and E2 = '0' and E3 = '1' then
            case A is
                when "000" =>
                    data_out(0) <= '0';
                    data_out(7 downto 1) <= (others => '1');
                when "001" =>
                    data_out(0) <= '1';
                    data_out(1) <= '0';
                    data_out(7 downto 2) <= (others => '1');
                when "010" =>
                    data_out(1 downto 0) <= (others => '1');
                    data_out(2) <= '0';
                    data_out(7 downto 3) <= (others => '1');
                when "011" =>
                    data_out(2 downto 0) <= (others => '1');
                    data_out(3) <= '0';
                    data_out(7 downto 4) <= (others => '1');
                when "100" =>
                    data_out(3 downto 0) <= (others => '1');
                    data_out(4) <= '0';
                    data_out(7 downto 5) <= (others => '1');
                when "101" =>
                    data_out(4 downto 0) <= (others => '1');
                    data_out(5) <= '0';
                    data_out(7 downto 6) <= (others => '1');
                when "110" =>
                    data_out(5 downto 0) <= (others => '1');
                    data_out(6) <= '0';
                    data_out(7) <= '1';
                when "111" =>
                    data_out(6 downto 0) <= (others => '1');
                    data_out(7) <= '0';
                when others => data_out <= (others => '1');
            end case;
        else
            data_out <= (others => '1');
        end if;
    end process;

    O <= data_out;

end rtl;
