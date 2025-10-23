library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity debouncer is
    generic(
        DEBOUNCE_TIME : integer := 2_000_000
    );
    port(
        clk : in std_logic;
        btn : in std_logic;
        btn_pressed : out std_logic
    );
end debouncer;

architecture rtl of debouncer is
    -- Button synchronization and edge detection
    signal btn_sync : std_logic_vector(1 downto 0) := "11"; -- Synchronized button (start released)
    signal btn_stable : std_logic := '1';                   -- Debounced button state
    signal btn_prev : std_logic := '1';                     -- Previous debounced state for edge detection

    signal debounce_counter : integer range 0 to DEBOUNCE_TIME := 0;

    signal btn_ready : std_logic := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then
            btn_sync <= btn_sync(0) & btn;

            -- Debounce logic
            if btn_sync(1) = btn_stable then
                -- Button stable, reset counter
                debounce_counter <= 0;
            else
                -- Button state changed, increment debounce counter
                if debounce_counter < DEBOUNCE_TIME then
                    debounce_counter <= debounce_counter + 1;
                else
                    -- Debounce time elapsed, update stable state
                    btn_stable <= btn_sync(1);
                    debounce_counter <= 0;
                end if;
            end if;

            -- Edge detection - detect falling edge BEFORE updating btn_prev
            -- Detect falling edge (button press: '1' -> '0')
            if btn_prev = '1' and btn_stable = '0' then
                btn_ready <= '1';
            else
                btn_ready <= '0';
            end if;

            -- Update previous state AFTER edge detection
            btn_prev <= btn_stable;
        end if;
    end process;

    btn_pressed <= btn_ready;

end rtl;