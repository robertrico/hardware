-------------------------------------------------------------------------------
-- Intel 8008 Silicon-Accurate Implementation
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Robert Rico
--
-- Cycle-accurate VHDL model of the Intel 8008 microprocessor.
-- This implementation models the actual hardware behavior, not just the ISA.
--
-- Pin-out matches the real Intel 8008 (18-pin DIP package):
--   - 8-bit multiplexed address/data bus (D0-D7)
--   - Two-phase non-overlapping clocks (φ1, φ2)
--   - State outputs (S0, S1, S2)
--   - SYNC output (timing reference)
--   - Control inputs (READY, INT)
--
-- Reference: Intel 8008 Datasheet (April 1974)
-- License: MIT (see LICENSE.txt)
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity s8008 is
    port (
        -- Two-phase clock inputs (non-overlapping)
        -- φ1: high for 0.8µs, then 0.4µs dead time
        -- φ2: high for 0.6µs, then 0.4µs dead time
        -- Total clock period: 2.2µs (φ1 rise to next φ1 rise)
        phi1 : in std_logic;
        phi2 : in std_logic;

        -- Reset (active low)
        reset_n : in std_logic;

        -- 8-bit multiplexed address/data bus (bidirectional)
        -- During T1: D7-D0 = A7-A0 (lower 8 bits of address)
        -- During T2: D7-D6 = cycle type, D5-D0 = A13-A8 (upper 6 bits of address)
        -- During T3: D7-D0 = data (read or write)
        data_bus : inout std_logic_vector(7 downto 0);

        -- State outputs (timing state indication)
        -- S2 S1 S0 = State encoding:
        --   000 = T1    (address low byte)
        --   001 = T1I   (interrupt acknowledge)
        --   010 = T2    (address high byte + cycle type)
        --   011 = WAIT  (wait state)
        --   100 = T3    (data transfer)
        --   101 = STOPPED (halted)
        --   110 = T4    (data hold)
        --   111 = T5    (cycle complete)
        S0 : out std_logic;
        S1 : out std_logic;
        S2 : out std_logic;

        -- SYNC output (timing reference)
        -- Per Intel datasheet: "divide by two of φ2"
        -- SYNC toggles every clock period to distinguish between
        -- the two clock periods within each state (T1-T5)
        SYNC : out std_logic;

        -- READY input (wait state control)
        -- When READY=0 during T2, CPU inserts wait states (TWAIT)
        -- When READY=1, CPU proceeds normally
        READY : in std_logic;

        -- Interrupt request input
        -- When INT=1 during T1, CPU performs interrupt acknowledge (T1I)
        INT : in std_logic
    );
end s8008;

architecture rtl of s8008 is

    --===========================================
    -- Internal Signals
    --===========================================

    -- Clock phase counter for two-clock-period states
    -- Per Intel 8008 datasheet: "Two clock periods are required for each state"
    -- One clock period = φ1 rise → φ1 fall → dead → φ2 rise → φ2 fall → dead → φ1 rise (2.2µs)
    -- Therefore each state (T1, T2, T3, T4, T5) spans TWO φ1 rising edges (4.4µs)
    signal clock_phase : std_logic := '0';  -- Toggles every φ1 edge

    -- Timing states (real 8008 hardware states)
    type timing_state_t is (T1, T1I, T2, TWAIT, T3, T4, T5, STOPPED);
    signal timing_state : timing_state_t := T1;

begin

    --===========================================
    -- Clock Phase Counter
    --===========================================
    -- Toggles every φ1 rising edge to create two-clock-period state timing
    -- This divides the state machine transitions in half:
    --   - First clock period (clock_phase='0'): Setup actions
    --   - Second clock period (clock_phase='1'): State transitions

    process(phi1, reset_n)
    begin
        if reset_n = '0' then
            clock_phase <= '0';
        elsif rising_edge(phi1) then
            clock_phase <= not clock_phase;
            report "Clock phase toggled to " & std_logic'image(not clock_phase) & " at " & time'image(now);
        end if;
    end process;

    --===========================================
    -- SYNC Signal Generation
    --===========================================
    -- Per Intel 8008 datasheet Figure 15:
    -- SYNC is HIGH during first clock period of ANY state (when clock_phase='0')
    -- SYNC is LOW during second clock period of ANY state (when clock_phase='1')
    -- This makes SYNC a true "divide by two" signal that distinguishes between
    -- the two clock periods within EVERY state (T1, T2, T3, T4, T5)

    SYNC <= not clock_phase;

    --===========================================
    -- State Output Encoding (S2, S1, S0)
    --===========================================
    -- Per Intel 8008 datasheet Table 1

    process(timing_state)
    begin
        case timing_state is
            when T1      => S2 <= '0'; S1 <= '0'; S0 <= '0';  -- 000
            when T1I     => S2 <= '0'; S1 <= '0'; S0 <= '1';  -- 001
            when T2      => S2 <= '0'; S1 <= '1'; S0 <= '0';  -- 010
            when TWAIT   => S2 <= '0'; S1 <= '1'; S0 <= '1';  -- 011
            when T3      => S2 <= '1'; S1 <= '0'; S0 <= '0';  -- 100
            when STOPPED => S2 <= '1'; S1 <= '0'; S0 <= '1';  -- 101
            when T4      => S2 <= '1'; S1 <= '1'; S0 <= '0';  -- 110
            when T5      => S2 <= '1'; S1 <= '1'; S0 <= '1';  -- 111
        end case;
    end process;

    --===========================================
    -- Timing State Machine
    --===========================================
    -- Implements the real 8008 hardware state sequencing
    -- Each state lasts TWO clock periods (4.4µs)
    -- Free-running: Always cycles T1→T2→T3→T4→T5→T1...

    process(phi1, reset_n)
        variable next_phase : std_logic;
    begin
        if reset_n = '0' then
            timing_state <= T1;

        elsif rising_edge(phi1) then
            -- Get next clock phase value immediately
            next_phase := not clock_phase;

            -- State transitions occur on second clock period only
            if next_phase = '1' then
                case timing_state is
                    when T1 =>
                        -- Check for interrupt request
                        if INT = '1' then
                            timing_state <= T1I;
                            report "T1 → T1I (interrupt)";
                        else
                            timing_state <= T2;
                            report "T1 → T2";
                        end if;

                    when T1I =>
                        timing_state <= T2;
                        report "T1I → T2";

                    when T2 =>
                        -- Check READY signal for wait states
                        if READY = '1' then
                            timing_state <= T3;
                            report "T2 → T3";
                        else
                            timing_state <= TWAIT;
                            report "T2 → TWAIT";
                        end if;

                    when TWAIT =>
                        -- Stay in wait until READY
                        if READY = '1' then
                            timing_state <= T3;
                            report "TWAIT → T3";
                        end if;

                    when T3 =>
                        timing_state <= T4;
                        report "T3 → T4";

                    when T4 =>
                        timing_state <= T5;
                        report "T4 → T5";

                    when T5 =>
                        -- Free-running: always return to T1
                        timing_state <= T1;
                        report "T5 → T1 (free-running cycle)";

                    when STOPPED =>
                        -- Remain stopped (HLT instruction executed)
                        null;
                end case;
            end if;
        end if;
    end process;

    --===========================================
    -- Data Bus Control
    --===========================================
    -- Placeholder: Tri-state for now
    -- TODO: Implement address/data multiplexing

    data_bus <= (others => 'Z');

end rtl;
