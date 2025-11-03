-------------------------------------------------------------------------------
-- I/O Console Component for Intel 8008
-------------------------------------------------------------------------------
-- Simple period-appropriate I/O console that interfaces with the 8008's
-- I/O port instructions (INP/OUT).
--
-- Port Map:
--   Port 0: Console TX Data (write only) - Write a character to console
--   Port 1: Console TX Status (read only) - bit 0 = ready (always 1)
--   Port 2: Console RX Data (read only) - Read character (not implemented)
--   Port 3: Console RX Status (read only) - bit 0 = data available (always 0)
--
-- This component uses VHDL TEXTIO to write characters to a file and
-- VHDL report statements to print characters to the simulation console.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;

entity io_console is
    generic(
        OUTPUT_FILE : string := "console_output.txt"
    );
    port(
        -- Clock and reset
        phi1 : in std_logic;
        phi2 : in std_logic;
        reset : in std_logic;

        -- 8008 I/O interface (connected to s8008 port_out signals)
        port_out : in std_logic_vector(7 downto 0);      -- Output data from CPU
        port_out_addr : in std_logic_vector(4 downto 0); -- Output port address
        port_out_strobe : in std_logic;                  -- Strobe when OUT executes
        port_in : out std_logic_vector(7 downto 0)       -- Input data to CPU (for INP)
    );
end io_console;

architecture rtl of io_console is

    -- File handling
    file output_file_handle : text;
    signal file_opened : boolean := false;

    -- Character accumulation for display
    signal char_count : integer := 0;

begin

    --===========================================
    -- Console Output Process
    --===========================================
    -- Handles OUT instructions to port 0
    -- Writes character to file and reports to console
    --===========================================
    console_tx: process(phi1)
        variable file_line : line;
        variable char : character;
        variable last_strobe : std_logic := '0';
    begin
        if rising_edge(phi1) then
            -- Open file on first use
            if not file_opened then
                file_open(output_file_handle, OUTPUT_FILE, write_mode);
                file_opened <= true;
                report "I/O Console: Output file opened: " & OUTPUT_FILE;
            end if;

            -- Check for OUT instruction to port 0 (Console TX Data)
            -- Only capture on rising edge of strobe to avoid duplicates
            if port_out_strobe = '1' and last_strobe = '0' and port_out_addr(2 downto 0) = "000" then
                -- Convert byte to character
                char := character'val(to_integer(unsigned(port_out)));

                -- Write to file (write single character, only use writeline for newlines)
                write(file_line, char);
                if port_out = x"0A" or port_out = x"0D" then
                    -- Only flush line on newline characters
                    writeline(output_file_handle, file_line);
                end if;

                -- Report to simulation console
                -- Use severity note for normal output
                if port_out = x"0A" then
                    report "I/O Console TX: [LF]" severity note;
                elsif port_out = x"0D" then
                    report "I/O Console TX: [CR]" severity note;
                elsif port_out >= x"20" and port_out <= x"7E" then
                    -- Printable ASCII
                    report "I/O Console TX: '" & char & "' (0x" &
                           to_hstring(port_out) & ")" severity note;
                else
                    -- Non-printable
                    report "I/O Console TX: [0x" & to_hstring(port_out) & "]" severity note;
                end if;

                -- Increment character counter
                char_count <= char_count + 1;
            end if;

            -- Track strobe for edge detection
            last_strobe := port_out_strobe;
        end if;
    end process;

    --===========================================
    -- Console Input Process
    --===========================================
    -- Handles INP instructions from ports 0-3
    -- Returns status/data based on port address
    --===========================================
    console_rx: process(port_out_addr)
    begin
        case port_out_addr(2 downto 0) is
            when "000" =>
                -- Port 0: TX Data (write-only, return 0)
                port_in <= x"00";

            when "001" =>
                -- Port 1: TX Status (bit 0 = ready, always 1)
                port_in <= x"01";

            when "010" =>
                -- Port 2: RX Data (not implemented, return 0)
                port_in <= x"00";

            when "011" =>
                -- Port 3: RX Status (not implemented, return 0)
                port_in <= x"00";

            when others =>
                -- Ports 4-7: Unused
                port_in <= x"00";
        end case;
    end process;

    --===========================================
    -- Simulation End Report
    --===========================================
    -- This process runs at the end of simulation
    -- to provide a summary of I/O activity
    --===========================================
    end_report: process
    begin
        wait for 1 sec;  -- Wait for simulation to complete
        report "========================================" severity note;
        report "I/O Console Summary" severity note;
        report "  Total characters output: " & integer'image(char_count) severity note;
        report "  Output file: " & OUTPUT_FILE severity note;
        report "========================================" severity note;
        wait;
    end process;

end rtl;
