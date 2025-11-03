-------------------------------------------------------------------------------
-- I/O Console Component for Intel 8008 (Bus-Based Interface)
-------------------------------------------------------------------------------
-- Bus-accurate I/O console that decodes I/O operations from the 8008's
-- multiplexed data bus, matching the real Intel 8008 hardware interface.
--
-- This console decodes PCC (I/O) cycles by monitoring the state signals and
-- data bus to determine when I/O operations occur, then either captures
-- output data or drives input data on the bus.
--
-- Port Map:
--   Port 0: Console TX Data (write only) - Write a character to console
--   Port 1: Console TX Status (read only) - bit 0 = ready (always 1)
--   Port 2: Console RX Data (read only) - Read character (not implemented)
--   Port 3: Console RX Status (read only) - bit 0 = data available (always 0)
--
-- Per Intel 8008 datasheet, I/O operations use PCC cycles (cycle type "10"):
--   T1 (S2S1S0=010): CPU outputs port address (00000MMM for INP, 000RRMMM for OUT)
--   T2 (S2S1S0=001): CPU outputs cycle type "10" on D7-D6
--   T3 (S2S1S0=100): Data transfer (OUT: CPU drives, INP: device drives)
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

        -- 8008 bus interface (matches real 8008 pins)
        S0 : in std_logic;                              -- State bit 0
        S1 : in std_logic;                              -- State bit 1
        S2 : in std_logic;                              -- State bit 2
        data_bus : inout std_logic_vector(7 downto 0)  -- Bidirectional data bus
    );
end io_console;

architecture rtl of io_console is

    -- File handling
    file output_file_handle : text;
    signal file_opened : boolean := false;

    -- Character accumulation for display
    signal char_count : integer := 0;

    -- I/O cycle decode signals
    signal port_addr : std_logic_vector(7 downto 0) := (others => '0');
    signal cycle_type : std_logic_vector(1 downto 0) := "00";
    signal is_io_cycle : boolean := false;
    signal is_read : boolean := false;  -- True for INP, false for OUT

    -- Bus driver control
    signal drive_bus : std_logic := '0';
    signal bus_data : std_logic_vector(7 downto 0) := (others => '0');

begin

    --===========================================
    -- I/O Cycle Decoder
    --===========================================
    -- Decodes PCC cycles from state signals and data bus
    -- Captures port address during T1 and cycle type during T2
    --===========================================
    cycle_decoder: process(phi1)
    begin
        if rising_edge(phi1) then
            if reset = '1' then
                port_addr <= (others => '0');
                cycle_type <= "00";
                is_io_cycle <= false;
                drive_bus <= '0';
            else
                -- T1 (S2S1S0 = 000): Capture port address from data bus
                if S2 = '0' and S1 = '0' and S0 = '0' then
                    port_addr <= data_bus;
                    is_io_cycle <= false;  -- Not confirmed as I/O yet
                    drive_bus <= '0';       -- Don't drive during T1
                    report "I/O Console: T1 detected, capturing port_addr from data_bus=0x" & to_hstring(unsigned(data_bus));

                -- T2 (S2S1S0 = 010): Capture cycle type from data bus
                elsif S2 = '0' and S1 = '1' and S0 = '0' then
                    cycle_type <= data_bus(7 downto 6);
                    report "I/O Console: T2 detected, data_bus=0x" & to_hstring(unsigned(data_bus)) &
                           ", cycle_type=" & std_logic'image(data_bus(7)) & std_logic'image(data_bus(6));
                    -- Check if this is a PCC cycle (I/O operation)
                    if data_bus(7 downto 6) = "10" then
                        is_io_cycle <= true;
                        -- Determine if INP or OUT based on port address
                        -- INP: port_addr bits 7-3 are all 0 (00000MMM)
                        -- OUT: port_addr bits 7-5 are 0, bits 4-3 can be non-zero (000RRMMM)
                        is_read <= (port_addr(7 downto 3) = "00000");
                        report "I/O Console: PCC cycle detected, port_addr=0x" & to_hstring(unsigned(port_addr)) &
                               ", is_read=" & boolean'image(port_addr(7 downto 3) = "00000");
                    else
                        is_io_cycle <= false;
                    end if;
                    drive_bus <= '0';  -- Don't drive during T2

                -- T3 (S2S1S0 = 100): Data transfer
                -- For INP (read), drive the bus
                -- For OUT (write), tri-state the bus (CPU drives it)
                elsif S2 = '1' and S1 = '0' and S0 = '0' then
                    if is_io_cycle and is_read then
                        -- INP: Drive input data on bus
                        drive_bus <= '1';
                    else
                        -- OUT or non-I/O: Don't drive bus
                        drive_bus <= '0';
                    end if;

                -- Other states: Don't drive bus
                else
                    drive_bus <= '0';
                end if;
            end if;
        end if;
    end process;

    --===========================================
    -- Console Input Data Generation
    --===========================================
    -- Generate input data based on port address
    -- This is purely combinatorial
    --===========================================
    input_data_gen: process(port_addr)
    begin
        case port_addr(2 downto 0) is
            when "000" =>
                -- Port 0: TX Data (write-only, return 0)
                bus_data <= x"00";

            when "001" =>
                -- Port 1: TX Status (bit 0 = ready, always 1)
                bus_data <= x"01";

            when "010" =>
                -- Port 2: RX Data (not implemented, return 0)
                bus_data <= x"00";

            when "011" =>
                -- Port 3: RX Status (not implemented, return 0)
                bus_data <= x"00";

            when others =>
                -- Ports 4-7: Unused
                bus_data <= x"00";
        end case;
    end process;

    -- Tri-state bus driver: only drive when drive_bus='1'
    data_bus <= bus_data when drive_bus = '1' else (others => 'Z');

    --===========================================
    -- Console Output Process
    --===========================================
    -- Handles OUT instructions to port 0
    -- Captures data during T3 of PCC write cycles
    --===========================================
    console_tx: process(phi1)
        variable file_line : line;
        variable char : character;
        variable last_state : std_logic_vector(2 downto 0) := "000";
        variable current_state : std_logic_vector(2 downto 0);
    begin
        if rising_edge(phi1) then
            current_state := S2 & S1 & S0;

            -- Open file on first use
            if not file_opened then
                file_open(output_file_handle, OUTPUT_FILE, write_mode);
                file_opened <= true;
                report "I/O Console: Output file opened: " & OUTPUT_FILE;
            end if;

            -- Detect rising edge of T3 (transition to S2S1S0=100)
            -- During T3 of an OUT to port 0
            if current_state = "100" and last_state /= "100" then
                if is_io_cycle and not is_read and port_addr(2 downto 0) = "000" then
                    -- Convert byte to character
                    char := character'val(to_integer(unsigned(data_bus)));

                    -- Write to file
                    write(file_line, char);
                    if data_bus = x"0A" or data_bus = x"0D" then
                        -- Flush line on newline characters
                        writeline(output_file_handle, file_line);
                    end if;

                    -- Report to simulation console
                    if data_bus = x"0A" then
                        report "I/O Console TX: [LF]" severity note;
                    elsif data_bus = x"0D" then
                        report "I/O Console TX: [CR]" severity note;
                    elsif data_bus >= x"20" and data_bus <= x"7E" then
                        -- Printable ASCII
                        report "I/O Console TX: '" & char & "' (0x" &
                               to_hstring(unsigned(data_bus)) & ")" severity note;
                    else
                        -- Non-printable
                        report "I/O Console TX: [0x" & to_hstring(unsigned(data_bus)) & "]" severity note;
                    end if;

                    -- Increment character counter
                    char_count <= char_count + 1;
                end if;
            end if;

            -- Track state for edge detection
            last_state := current_state;
        end if;
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
