-------------------------------------------------------------------------------
-- 8008 Bus Timing Controller
-------------------------------------------------------------------------------
-- Generates timing and control signals for 8008 memory/IO interfacing
--
-- Function:
-- - Tracks T1/T2/T3/T4/T5 bus cycle states using SYNC and S0/S1/S2 signals
-- - Generates address latch strobes
-- - Generates memory/IO control signals
-- - Handles free-running SYNC pulses (continuous T1-T5 cycles)
--
-- Based on Intel 8008 datasheet timing diagrams
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity timing_controller_8008 is
    port(
        -- Clock (phi1 - sample on rising edge to sync with CPU internal state)
        phi1 : in std_logic;
        reset_n : in std_logic;

        -- 8008 CPU outputs
        SYNC : in std_logic;
        S0 : in std_logic;
        S1 : in std_logic;
        S2 : in std_logic;

        -- Timing state outputs
        state_T1 : out std_logic;
        state_T2 : out std_logic;
        state_T3 : out std_logic;

        -- Address latch control
        latch_low_enable : out std_logic;   -- Enable for lower address latch
        latch_high_enable : out std_logic   -- Enable for upper address latch
    );
end timing_controller_8008;

architecture rtl of timing_controller_8008 is
    type bus_state_t is (T1, T2, T3_T4_T5, IDLE);
    signal current_state : bus_state_t := IDLE;
    signal prev_sync : std_logic := '0';

begin
    process(phi1, reset_n)
    begin
        if reset_n = '0' then
            current_state <= IDLE;
            prev_sync <= '0';

        elsif rising_edge(phi1) then
            -- State machine
            case current_state is
                when IDLE =>
                    -- Wait for SYNC rising edge (start of new T1)
                    if SYNC = '1' and prev_sync = '0' then
                        current_state <= T1;
                        report "Timing Controller: IDLE->T1 (SYNC rising edge)";
                    end if;

                when T1 =>
                    -- T1: SYNC is high, lower address on bus
                    if SYNC = '0' then
                        -- SYNC falling: transition to T2
                        current_state <= T2;
                        report "Timing Controller: T1->T2 (SYNC falling edge)";
                    end if;

                when T2 =>
                    -- T2: Upper address + cycle type on bus
                    current_state <= T3_T4_T5;
                    report "Timing Controller: T2->T3_T4_T5";

                when T3_T4_T5 =>
                    -- T3/T4/T5: Data transfer and cycle completion
                    -- Stay here until next SYNC pulse
                    if SYNC = '1' and prev_sync = '0' then
                        -- New cycle starting
                        current_state <= T1;
                        report "Timing Controller: T3_T4_T5->T1 (SYNC rising edge)";
                    end if;
            end case;

            -- Track SYNC for edge detection
            prev_sync <= SYNC;
        end if;
    end process;

    -- Combinational outputs based on current state
    -- These are level-sensitive, active for the duration of each state
    state_T1 <= '1' when current_state = T1 else '0';
    state_T2 <= '1' when current_state = T2 else '0';
    state_T3 <= '1' when current_state = T3_T4_T5 else '0';

    -- Latch enables: Generate pulses at the right moments
    -- The 8212 is transparent when STB=1, and latches when STB falls to 0
    -- We want to latch at the END of T1 and END of T2, so:
    -- - Lower latch: STB high during T1, falls at T1->T2 transition
    -- - Upper latch: STB high during T2, falls at T2->T3 transition
    latch_low_enable <= '1' when current_state = T1 else '0';      -- High during T1, latches on T1->T2 edge
    latch_high_enable <= '1' when current_state = T2 else '0';     -- High during T2, latches on T2->T3 edge

end rtl;
