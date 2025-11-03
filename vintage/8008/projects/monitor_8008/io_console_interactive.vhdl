-------------------------------------------------------------------------------
-- Interactive I/O Console for Intel 8008 (Bus-Based with VHPIDIRECT)
-------------------------------------------------------------------------------
-- Bus-accurate I/O console that decodes I/O operations from the 8008's
-- multiplexed data bus and provides real terminal I/O using VHPIDIRECT.
--
-- This console decodes PCC (I/O) cycles by monitoring the state signals and
-- data bus to determine when I/O operations occur, then either captures
-- output data or drives input data on the bus.
--
-- Port Map:
--   Port 0: Console TX Data (write only) - Output character to terminal
--   Port 1: Console TX Status (read only) - Always ready (0x01)
--   Port 2: Console RX Data (read only) - Read character from keyboard (BLOCKS!)
--   Port 3: Console RX Status (read only) - bit 0 = key available
--
-- VHPIDIRECT Integration:
--   Uses C functions for real terminal I/O:
--   - console_putc(char) - Write to terminal
--   - console_getc()     - Read from keyboard (BLOCKS!)
--   - console_kbhit()    - Check if key available
--
-- Per Intel 8008 datasheet, I/O operations use PCC cycles (cycle type "10"):
--   T1 (S2S1S0=000): CPU outputs port address (00000MMM for INP, 000RRMMM for OUT)
--   T2 (S2S1S0=010): CPU outputs cycle type "10" on D7-D6
--   T3 (S2S1S0=100): Data transfer (OUT: CPU drives, INP: device drives)
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

        -- 8008 bus interface (matches real 8008 pins)
        S0 : in std_logic;                              -- State bit 0
        S1 : in std_logic;                              -- State bit 1
        S2 : in std_logic;                              -- State bit 2
        data_bus : inout std_logic_vector(7 downto 0)  -- Bidirectional data bus
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
        -- report "VHPIDIRECT console_putc" severity failure;
    end console_putc;

    function console_kbhit return integer is
    begin
        -- report "VHPIDIRECT console_kbhit" severity failure;
        return 0;
    end console_kbhit;

    function console_getc return integer is
    begin
        -- report "VHPIDIRECT console_getc" severity failure;
        return 0;
    end console_getc;

    -- I/O cycle decode signals
    signal port_addr : std_logic_vector(7 downto 0) := (others => '0');
    signal cycle_type : std_logic_vector(1 downto 0) := "00";
    signal is_io_cycle : boolean := false;
    signal is_read : boolean := false;  -- True for INP, false for OUT

    -- Bus driver control
    signal drive_bus : std_logic := '0';
    signal bus_data : std_logic_vector(7 downto 0) := (others => '0');

    -- Character tracking
    signal char_count : integer := 0;
    signal last_rx_char : std_logic_vector(7 downto 0) := x"00";
    signal need_new_char : boolean := false;
    signal last_need_new_char : boolean := false;

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
                need_new_char <= false;
            else
                -- T1 (S2S1S0 = 000): Capture port address from data bus
                if S2 = '0' and S1 = '0' and S0 = '0' then
                    port_addr <= data_bus;
                    is_io_cycle <= false;  -- Not confirmed as I/O yet
                    drive_bus <= '0';       -- Don't drive during T1
                    need_new_char <= false;

                -- T2 (S2S1S0 = 010): Capture cycle type from data bus
                elsif S2 = '0' and S1 = '1' and S0 = '0' then
                    cycle_type <= data_bus(7 downto 6);
                    -- Check if this is a PCC cycle (I/O operation)
                    if data_bus(7 downto 6) = "10" then
                        is_io_cycle <= true;
                        -- Determine if INP or OUT based on port address
                        -- INP: port_addr bits 7-3 are all 0 (00000MMM)
                        -- OUT: port_addr bits 7-5 are 0, bits 4-3 can be non-zero (000RRMMM)
                        is_read <= (port_addr(7 downto 3) = "00000");

                        -- Special: Mark need for new character if reading from port 2
                        if port_addr(7 downto 3) = "00000" and port_addr(2 downto 0) = "010" then
                            need_new_char <= true;
                        end if;
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
                    need_new_char <= false;  -- Clear flag after T3

                -- Other states: Don't drive bus
                else
                    drive_bus <= '0';
                end if;
            end if;
        end if;
    end process;

    --===========================================
    -- Console Input Character Fetch
    --===========================================
    -- Fetch new character from terminal when accessing port 2
    -- This is THE BLOCKING CALL that pauses simulation!
    --===========================================
    rx_fetch: process(phi1)
        variable key_char : integer;
    begin
        if rising_edge(phi1) then
            if reset = '1' then
                last_rx_char <= x"00";
                last_need_new_char <= false;
            else
                -- Only fetch on rising edge of need_new_char (edge detection)
                if need_new_char and not last_need_new_char then
                    -- BLOCKING CALL: Simulation pauses here until keypress!
                    key_char := console_getc;
                    last_rx_char <= std_logic_vector(to_unsigned(key_char, 8));
                    report "Console RX: Read character 0x" & to_hstring(to_unsigned(key_char, 8)) &
                           " ('" & character'val(key_char) & "')";
                end if;
                -- Track previous state for edge detection
                last_need_new_char <= need_new_char;
            end if;
        end if;
    end process;

    --===========================================
    -- Console Input Data Generation
    --===========================================
    -- Generate input data based on port address
    -- This is purely combinatorial
    --===========================================
    input_data_gen: process(port_addr, last_rx_char)
        variable key_status : integer;
    begin
        case port_addr(2 downto 0) is
            when "000" =>
                -- Port 0: TX Data (write-only, return 0)
                bus_data <= x"00";

            when "001" =>
                -- Port 1: TX Status (always ready)
                bus_data <= x"01";

            when "010" =>
                -- Port 2: RX Data
                -- Return the last character fetched by rx_fetch process
                bus_data <= last_rx_char;

            when "011" =>
                -- Port 3: RX Status (check if key available)
                key_status := console_kbhit;
                if key_status = 1 then
                    bus_data <= x"01";  -- Key available
                else
                    bus_data <= x"00";  -- No key available
                end if;

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
        variable char : character;
        variable last_state : std_logic_vector(2 downto 0) := "000";
        variable current_state : std_logic_vector(2 downto 0);
    begin
        if rising_edge(phi1) then
            current_state := S2 & S1 & S0;

            -- Detect rising edge of T3 (transition to S2S1S0=100)
            -- During T3 of an OUT to port 0
            if current_state = "100" and last_state /= "100" then
                if is_io_cycle and not is_read and port_addr(2 downto 0) = "000" then
                    -- Convert byte to character
                    char := character'val(to_integer(unsigned(data_bus)));

                    -- Call C function to output to terminal
                    console_putc(char);

                    -- Increment character counter
                    char_count <= char_count + 1;
                end if;
            end if;

            -- Track state for edge detection
            last_state := current_state;
        end if;
    end process;

end rtl;
