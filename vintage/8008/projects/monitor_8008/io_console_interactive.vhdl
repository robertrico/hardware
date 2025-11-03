-------------------------------------------------------------------------------
-- Interactive I/O Console for Intel 8008 (VHPIDIRECT version)
-------------------------------------------------------------------------------
-- Provides real terminal I/O using C functions via GHDL's VHPIDIRECT
--
-- Port Map:
--   Port 0: Console TX Data (write only) - Output character to terminal
--   Port 1: Console TX Status (read only) - Always ready (0x01)
--   Port 2: Console RX Data (read only) - Read character from keyboard (BLOCKS!)
--   Port 3: Console RX Status (read only) - bit 0 = key available
--
-- This version provides REAL interactive I/O:
-- - OUT 0: Immediately writes to your terminal
-- - INP 2: BLOCKS simulation until you press a key (real input!)
-- - INP 3: Returns 1 if key is available, 0 otherwise
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity io_console_interactive is
    port(
        -- Clock and reset
        phi1 : in std_logic;
        phi2 : in std_logic;
        reset : in std_logic;

        -- 8008 I/O interface
        port_out : in std_logic_vector(7 downto 0);
        port_out_addr : in std_logic_vector(4 downto 0);
        port_out_strobe : in std_logic;
        port_in : out std_logic_vector(7 downto 0)
    );
end io_console_interactive;

architecture rtl of io_console_interactive is

    --===========================================
    -- VHPIDIRECT Function Declarations
    --===========================================
    -- These are C functions that VHDL can call

    -- Output character to terminal
    procedure console_putc(c : in character);
    attribute foreign of console_putc : procedure is "VHPIDIRECT console_putc";

    -- Check if key is available (non-blocking)
    function console_kbhit return integer;
    attribute foreign of console_kbhit : function is "VHPIDIRECT console_kbhit";

    -- Read character from terminal (BLOCKING - waits for keypress!)
    function console_getc return integer;
    attribute foreign of console_getc : function is "VHPIDIRECT console_getc";

    -- Dummy implementations (never called, required by VHDL standard)
    procedure console_putc(c : in character) is
    begin
        report "VHPIDIRECT console_putc" severity failure;
    end console_putc;

    function console_kbhit return integer is
    begin
        report "VHPIDIRECT console_kbhit" severity failure;
        return 0;
    end console_kbhit;

    function console_getc return integer is
    begin
        report "VHPIDIRECT console_getc" severity failure;
        return 0;
    end console_getc;

    -- Internal signals
    signal last_strobe : std_logic := '0';
    signal char_count : integer := 0;
    signal last_rx_char : std_logic_vector(7 downto 0) := x"00";
    signal last_port_addr : std_logic_vector(2 downto 0) := "000";

begin

    --===========================================
    -- Console Output Process
    --===========================================
    console_tx: process(phi1)
        variable char : character;
    begin
        if rising_edge(phi1) then
            -- Check for OUT instruction to port 0 (Console TX Data)
            if port_out_strobe = '1' and last_strobe = '0' and port_out_addr(2 downto 0) = "000" then
                -- Convert byte to character
                char := character'val(to_integer(unsigned(port_out)));

                -- Call C function to output to terminal
                console_putc(char);

                -- Increment counter
                char_count <= char_count + 1;
            end if;

            -- Track strobe for edge detection
            last_strobe <= port_out_strobe;
        end if;
    end process;

    --===========================================
    -- Console Input Character Fetch
    --===========================================
    -- Synchronous process to fetch new character when port 2 is accessed
    -- Only calls console_getc() once per transition to port 2
    --===========================================
    rx_fetch: process(phi1)
        variable key_char : integer;
    begin
        if rising_edge(phi1) then
            -- Detect transition TO port 2 (edge detection)
            if port_out_addr(2 downto 0) = "010" and last_port_addr /= "010" then
                -- New read from port 2 - fetch character (BLOCKS!)
                key_char := console_getc;
                last_rx_char <= std_logic_vector(to_unsigned(key_char, 8));
            end if;

            -- Remember last port address
            last_port_addr <= port_out_addr(2 downto 0);
        end if;
    end process;

    --===========================================
    -- Console Input Multiplexer
    --===========================================
    -- Combinational process to select input data based on port address
    --===========================================
    console_rx: process(port_out_addr, last_rx_char)
        variable key_status : integer;
    begin
        case port_out_addr(2 downto 0) is
            when "000" =>
                -- Port 0: TX Data (write-only, return 0)
                port_in <= x"00";

            when "001" =>
                -- Port 1: TX Status (always ready)
                port_in <= x"01";

            when "010" =>
                -- Port 2: RX Data
                -- Return the last character fetched by rx_fetch process
                port_in <= last_rx_char;

            when "011" =>
                -- Port 3: RX Status (check if key available)
                key_status := console_kbhit;
                if key_status = 1 then
                    port_in <= x"01";  -- Key available
                else
                    port_in <= x"00";  -- No key available
                end if;

            when others =>
                -- Ports 4-7: Unused
                port_in <= x"00";
        end case;
    end process;

end rtl;
