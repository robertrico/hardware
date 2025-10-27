-- 8008_clock_gen.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity phase_clocks is
    Port ( 
        clk_in : in STD_LOGIC;
        reset  : in STD_LOGIC;
        phi1   : out STD_LOGIC;
        phi2   : out STD_LOGIC
    );
end phase_clocks;

architecture rtl of phase_clocks is
    type clk_phase is (PHI_1, PHI_2, DEAD_PHI, DEAD_PHI_2);
    constant CLOCK_DIVIDER : integer := 200;
    constant DEAD_CLOCK_DIVIDER : integer := 50;
    signal counter : integer := 0;
    signal current_phase : clk_phase;
begin
    process(clk_in, reset)
    begin
        if reset = '1' then
            counter <= 0;
            phi1 <= '1';
            phi2 <= '0';
            current_phase <= PHI_1;
        elsif rising_edge(clk_in) then
            if counter = DEAD_CLOCK_DIVIDER - 1 and current_phase = DEAD_PHI then
                current_phase <= PHI_1;
                phi1 <= '1';
                counter <= 0;
            elsif counter = DEAD_CLOCK_DIVIDER - 1 and current_phase = DEAD_PHI_2 then
                current_phase <= PHI_2;
                phi2 <= '1';
                counter <= 0;
            elsif counter = CLOCK_DIVIDER - 1 then
                counter <= 0;
                case current_phase is
                    when PHI_1 => phi1 <= '0'; phi2 <= '0'; current_phase <= DEAD_PHI_2;
                    when PHI_2 => phi1 <= '0'; phi2 <= '0'; current_phase <= DEAD_PHI;
                    when others => phi1 <= '0'; phi2 <='0'; current_phase <= PHI_1;
                end case;
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;
end rtl;