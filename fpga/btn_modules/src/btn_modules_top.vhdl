-- Top-level wrapper for synthesis
-- This wrapper hides the btns_pressed debug output to avoid wasting pins
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity btn_modules_top is
    generic (
        CLK_FREQ : integer := 100_000_000
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        btns : in std_logic_vector(3 downto 0);
        led : out std_logic_vector(7 downto 0)
    );
end btn_modules_top;

architecture rtl of btn_modules_top is
    component btn_modules is
        generic (
            CLK_FREQ : integer := 100_000_000
        );
        port (
            clk : in std_logic;
            rst : in std_logic;
            btns : in std_logic_vector(3 downto 0);
            led : out std_logic_vector(7 downto 0);
            btns_pressed : out std_logic_vector(7 downto 0)
        );
    end component;

    -- Internal signal to capture btns_pressed (will be optimized away)
    signal btns_pressed_unused : std_logic_vector(7 downto 0);

begin
    -- Instantiate the actual design
    core: btn_modules
        generic map (
            CLK_FREQ => CLK_FREQ
        )
        port map (
            clk => clk,
            rst => rst,
            btns => btns,
            led => led,
            btns_pressed => btns_pressed_unused  -- Not connected to output
        );

end rtl;
