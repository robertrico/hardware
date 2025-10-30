-------------------------------------------------------------------------------
-- Two-Phase Non-Overlapping Clock Generator for Intel 8008
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Robert Rico
--
-- Generates PHI1 and PHI2 clock phases with proper timing for Intel 8008:
--   - PHI1: 0.8 µs pulse width
--   - Dead time: 0.4 µs
--   - PHI2: 0.6 µs pulse width
--   - Dead time: 0.4 µs
--   - Total cycle: 2.2 µs (within 3 µs max cycle time)
--
-- License: MIT (see LICENSE.txt)
-------------------------------------------------------------------------------

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

    -- Intel 8008 Timing Constraints (assuming 100 MHz input clock = 10ns period):
    -- Max cycle time: 3 µs (rising PHI1 to next rising PHI1)
    -- Min PHI1 pulse width: 0.7 µs (70 clocks @ 100 MHz)
    -- Min PHI2 pulse width: 0.55 µs (55 clocks @ 100 MHz)

    -- Timing configuration:
    -- PHI1: 0.8 µs (80 clocks) - exceeds 0.7 µs minimum
    -- Dead time 1: 0.4 µs (40 clocks)
    -- PHI2: 0.6 µs (60 clocks) - exceeds 0.55 µs minimum
    -- Dead time 2: 0.4 µs (40 clocks)
    -- Total cycle: 2.2 µs - meets 3 µs maximum

    constant PHI1_DIVIDER : integer := 80;    -- 0.8 µs PHI1 pulse width
    constant PHI2_DIVIDER : integer := 60;    -- 0.6 µs PHI2 pulse width
    constant DEAD_DIVIDER : integer := 40;    -- 0.4 µs dead time

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
            case current_phase is
                -- PHI1 active phase
                when PHI_1 =>
                    if counter = PHI1_DIVIDER - 1 then
                        phi1 <= '0';
                        phi2 <= '0';
                        current_phase <= DEAD_PHI_2;
                        counter <= 0;
                    else
                        counter <= counter + 1;
                    end if;

                -- Dead time before PHI2
                when DEAD_PHI_2 =>
                    if counter = DEAD_DIVIDER - 1 then
                        phi2 <= '1';
                        current_phase <= PHI_2;
                        counter <= 0;
                    else
                        counter <= counter + 1;
                    end if;

                -- PHI2 active phase
                when PHI_2 =>
                    if counter = PHI2_DIVIDER - 1 then
                        phi1 <= '0';
                        phi2 <= '0';
                        current_phase <= DEAD_PHI;
                        counter <= 0;
                    else
                        counter <= counter + 1;
                    end if;

                -- Dead time before PHI1
                when DEAD_PHI =>
                    if counter = DEAD_DIVIDER - 1 then
                        phi1 <= '1';
                        current_phase <= PHI_1;
                        counter <= 0;
                    else
                        counter <= counter + 1;
                    end if;

            end case;
        end if;
    end process;
end rtl;