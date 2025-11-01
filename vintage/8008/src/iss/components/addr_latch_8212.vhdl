-------------------------------------------------------------------------------
-- 8212 8-bit I/O Port (Address Latch) for Intel 8008
-------------------------------------------------------------------------------
-- Models the Intel 8212 chip used in 8008 systems for address latching
--
-- Function: Transparent latch that captures and holds address bytes
-- - Transparent when STB (strobe) is high
-- - Latches data on falling edge of STB
-- - Holds data stable after STB goes low
--
-- In 8008 systems:
-- - Two 8212s are used: one for lower address, one for upper + cycle type
-- - STB is connected to SYNC signal
-- - Data is latched from multiplexed address/data bus
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity addr_latch_8212 is
    port(
        -- Data input (from CPU data bus)
        DI : in std_logic_vector(7 downto 0);

        -- Strobe input (connected to SYNC in 8008 systems)
        STB : in std_logic;

        -- Latched data output
        DO : out std_logic_vector(7 downto 0)
    );
end addr_latch_8212;

architecture rtl of addr_latch_8212 is
    signal latched_data : std_logic_vector(7 downto 0) := (others => '0');
begin
    -- Latch on falling edge of STB (8212 behavior)
    -- In real hardware this is a transparent latch, but for FPGA we use edge-triggered
    process(STB)
    begin
        if falling_edge(STB) then
            -- Latch data on STB falling edge
            latched_data <= DI;
            report "8212 Latch: Captured data=0x" & to_hstring(DI) & " on STB falling edge";
        end if;
    end process;

    -- Drive output
    DO <= latched_data;

end rtl;
