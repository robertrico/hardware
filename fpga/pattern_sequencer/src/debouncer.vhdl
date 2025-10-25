library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity debouncer is
    generic(
        DEBOUNCE_TIME : integer := 2_000_000
    );
    port(
        clk : in std_logic;
        rst : in std_logic;  -- Active low reset
        btn : in std_logic;
        btn_pressed : out std_logic
    );
end debouncer;

architecture rtl of debouncer is
    signal btn_sync : std_logic_vector(1 downto 0) := "11";
    signal btn_stable : std_logic := '1';
    signal btn_prev : std_logic := '1';
    signal debounce_counter : integer range 0 to DEBOUNCE_TIME := 0;
    signal btn_ready : std_logic := '0';

begin

    process(clk, rst)
    begin
        if rst = '0' then  -- Active low reset
            btn_sync <= "11";
            btn_stable <= '1';
            btn_prev <= '1';
            debounce_counter <= 0;
            btn_ready <= '0';
        elsif rising_edge(clk) then
            -- Synchronizer chain
            btn_sync <= btn_sync(0) & btn;

            -- Debounce logic
            if btn_sync(1) = btn_stable then
                debounce_counter <= 0;
            else
                if debounce_counter < DEBOUNCE_TIME then
                    debounce_counter <= debounce_counter + 1;
                else
                    btn_stable <= btn_sync(1);
                    debounce_counter <= 0;
                end if;
            end if;

            -- Edge detection: falling edge (button press '1' -> '0')
            if btn_prev = '1' and btn_stable = '0' then
                btn_ready <= '1';
            else
                btn_ready <= '0';
            end if;

            btn_prev <= btn_stable;
        end if;
    end process;

    btn_pressed <= btn_ready;

end rtl;