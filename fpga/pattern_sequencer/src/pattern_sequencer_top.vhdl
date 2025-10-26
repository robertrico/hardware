-- Minimal top-level wrapper for pattern_sequencer
-- Only exposes essential hardware pins, keeps debug signals internal
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pattern_sequencer_pkg.all;

entity pattern_sequencer_top is
    generic (
        CLK_FREQ : integer := 100_000_000  -- 100 MHz on ECP5 Versa board
    );
    port (
        clk       : in std_logic;
        rst       : in std_logic;
        speed_btn : in std_logic;
        led_btn   : in std_logic;
        leds      : out std_logic_vector(7 downto 0)
    );
end pattern_sequencer_top;

architecture rtl of pattern_sequencer_top is
    -- Component declaration
    component pattern_sequencer is
        generic (
            CLK_FREQ : integer := 100_000_000
        );
        port (
            clk          : in std_logic;
            rst          : in std_logic;
            speed_btn    : in std_logic;
            led_btn      : in std_logic;
            leds         : out std_logic_vector(7 downto 0);
            speed_change : out std_logic;
            cur_pat      : out led_pattern
        );
    end component;

    -- Internal signals for debug outputs (not exposed)
    signal speed_change_internal : std_logic;
    signal cur_pat_internal      : led_pattern;

begin
    -- Instantiate the main pattern_sequencer
    u_pattern_sequencer : pattern_sequencer
        generic map (
            CLK_FREQ => CLK_FREQ
        )
        port map (
            clk          => clk,
            rst          => rst,
            speed_btn    => speed_btn,
            led_btn      => led_btn,
            leds         => leds,
            speed_change => speed_change_internal,
            cur_pat      => cur_pat_internal
        );

end rtl;
