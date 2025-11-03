-------------------------------------------------------------------------------
-- Test: INP Instruction - Load Register A from I/O Port
-------------------------------------------------------------------------------
-- Verifies that the INP instruction correctly loads data from an I/O port
-- into the accumulator (register A).
--
-- Test program:
--   1. INP 2 - Read from I/O port 2 (should load 0x48 into A)
--   2. OUT 8 - Output the value in A to port 8
--   3. HLT - Stop execution
--
-- Expected behavior:
--   - INP 2 reads 0x48 from port 2 and stores it in register A
--   - OUT 8 outputs the value from A (0x48) to port 8
--   - The test verifies that register A = 0x48 and output = 0x48
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity s8008_inp_cpi_tb is
end s8008_inp_cpi_tb;

architecture sim of s8008_inp_cpi_tb is

    -- Component declarations
    component phase_clocks is
        port(
            clk_in : in std_logic;
            reset : in std_logic;
            phi1 : out std_logic;
            phi2 : out std_logic
        );
    end component;

    component s8008 is
        port(
            phi1 : in std_logic;
            phi2 : in std_logic;
            reset_n : in std_logic;
            data_bus : inout std_logic_vector(7 downto 0);
            S0 : out std_logic;
            S1 : out std_logic;
            S2 : out std_logic;
            SYNC : out std_logic;
            READY : in std_logic;
            INT : in std_logic;
            debug_reg_A : out std_logic_vector(7 downto 0);
            debug_reg_B : out std_logic_vector(7 downto 0);
            debug_reg_C : out std_logic_vector(7 downto 0);
            debug_reg_D : out std_logic_vector(7 downto 0);
            debug_reg_E : out std_logic_vector(7 downto 0);
            debug_reg_H : out std_logic_vector(7 downto 0);
            debug_reg_L : out std_logic_vector(7 downto 0);
            debug_pc : out std_logic_vector(13 downto 0);
            debug_flags : out std_logic_vector(3 downto 0)
        );
    end component;

    -- Clock and reset
    signal master_clk_tb : std_logic := '0';
    signal phi1_tb : std_logic := '0';
    signal phi2_tb : std_logic := '0';
    signal reset_tb : std_logic := '1';
    signal reset_n_tb : std_logic := '0';

    -- CPU signals
    signal data_tb : std_logic_vector(7 downto 0);
    signal S0_tb : std_logic;
    signal S1_tb : std_logic;
    signal S2_tb : std_logic;
    signal SYNC_tb : std_logic;
    signal READY_tb : std_logic := '1';
    signal INT_tb : std_logic := '0';

    -- Debug signals
    signal debug_reg_A_tb : std_logic_vector(7 downto 0);
    signal debug_reg_B_tb : std_logic_vector(7 downto 0);
    signal debug_pc_tb : std_logic_vector(13 downto 0);
    signal debug_flags_tb : std_logic_vector(3 downto 0);

    -- Master clock period (consistent with other testbenches)
    constant MASTER_CLK_PERIOD : time := 10 ns;  -- 100 MHz master clock

    -- ROM for test program
    type rom_array is array (0 to 255) of std_logic_vector(7 downto 0);
    constant ROM : rom_array := (
        -- Test: INP loads register A from I/O port
        0 => x"45",  -- INP 2 (read from input port 2)
        1 => x"51",  -- OUT 8 (output register A to port 8)
        2 => x"00",  -- HLT

        others => x"00"
    );

    -- Memory controller signals
    signal rom_data : std_logic_vector(7 downto 0) := (others => 'Z');
    signal rom_enable : std_logic := '0';

    -- I/O signals (separate from memory)
    signal io_port_addr : std_logic_vector(7 downto 0) := (others => '0');
    signal io_cycle_type : std_logic_vector(1 downto 0) := "00";
    signal is_io_cycle : boolean := false;
    signal is_io_read : boolean := false;
    signal io_bus_data : std_logic_vector(7 downto 0) := (others => '0');
    signal io_drive_bus : std_logic := '0';
    signal console_input_data : std_logic_vector(7 downto 0) := x"48";  -- 'H'
    signal last_output : std_logic_vector(7 downto 0) := x"00";

    -- Test tracking
    signal test_complete : boolean := false;

begin

    -- Bus driver (combines ROM and I/O bus control)
    data_tb <= rom_data when rom_enable = '1' else
               io_bus_data when io_drive_bus = '1' else
               (others => 'Z');

    -- Instantiate the CPU
    uut: s8008
        port map (
            phi1 => phi1_tb,
            phi2 => phi2_tb,
            reset_n => reset_n_tb,
            data_bus => data_tb,
            S0 => S0_tb,
            S1 => S1_tb,
            S2 => S2_tb,
            sync => SYNC_tb,
            ready => READY_tb,
            int => INT_tb,
            debug_reg_A => debug_reg_A_tb,
            debug_reg_B => debug_reg_B_tb,
            debug_reg_C => open,
            debug_reg_D => open,
            debug_reg_E => open,
            debug_reg_H => open,
            debug_reg_L => open,
            debug_pc => debug_pc_tb,
            debug_flags => debug_flags_tb
        );

    -- Instantiate phase clock generator
    clk_gen: phase_clocks
        port map (
            clk_in => master_clk_tb,
            reset => reset_tb,
            phi1 => phi1_tb,
            phi2 => phi2_tb
        );

    -- Master clock generation
    master_clk_process: process
    begin
        while not test_complete loop
            master_clk_tb <= '0';
            wait for MASTER_CLK_PERIOD / 2;
            master_clk_tb <= '1';
            wait for MASTER_CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Memory controller (ROM interface only)
    memory_controller: process(phi1_tb)
        variable captured_address : std_logic_vector(13 downto 0) := (others => '0');
        variable cycle_type : std_logic_vector(1 downto 0) := "00";
        variable is_write : boolean := false;
    begin
        if rising_edge(phi1_tb) then
            -- T1: Capture low address byte
            if S2_tb = '0' and S1_tb = '0' and S0_tb = '0' then
                if data_tb /= "ZZZZZZZZ" then
                    captured_address(7 downto 0) := data_tb;
                end if;
            end if;

            -- T2: Capture high address bits and cycle type
            if S2_tb = '0' and S1_tb = '1' and S0_tb = '0' then
                if data_tb /= "ZZZZZZZZ" then
                    cycle_type := data_tb(7 downto 6);
                    captured_address(13 downto 8) := data_tb(5 downto 0);
                    is_write := (cycle_type = "10");
                end if;
            end if;

            -- T3: Enable ROM for read cycles only (not I/O)
            if S2_tb = '1' and S1_tb = '0' and S0_tb = '0' then
                if is_write then
                    rom_enable <= '0';
                    rom_data <= (others => 'Z');
                else
                    rom_enable <= '1';
                    rom_data <= ROM(to_integer(unsigned(captured_address(7 downto 0))));
                end if;
            else
                rom_enable <= '0';
                rom_data <= (others => 'Z');
            end if;
        end if;
    end process;

    -- I/O cycle decoder (separate from memory)
    io_cycle_decoder: process(phi1_tb)
    begin
        if rising_edge(phi1_tb) then
            if reset_tb = '1' then
                io_port_addr <= (others => '0');
                io_cycle_type <= "00";
                is_io_cycle <= false;
                io_drive_bus <= '0';
            else
                -- T1 (S2S1S0 = 000): Capture port address from data bus
                if S2_tb = '0' and S1_tb = '0' and S0_tb = '0' then
                    if data_tb /= "ZZZZZZZZ" then
                        io_port_addr <= data_tb;
                        report "IO T1: port_addr=0x" & to_hstring(unsigned(data_tb));
                    end if;
                    is_io_cycle <= false;  -- Not confirmed as I/O yet
                    io_drive_bus <= '0';   -- Don't drive during T1

                -- T2 (S2S1S0 = 010): Capture cycle type from data bus
                elsif S2_tb = '0' and S1_tb = '1' and S0_tb = '0' then
                    if data_tb /= "ZZZZZZZZ" then
                        io_cycle_type <= data_tb(7 downto 6);
                        report "IO T2: cycle_type=" & std_logic'image(data_tb(7)) & std_logic'image(data_tb(6));
                        -- Check if this is a PCC cycle (I/O operation)
                        if data_tb(7 downto 6) = "10" then
                            is_io_cycle <= true;
                            -- Determine if INP or OUT based on port address
                            -- INP: port_addr bits 7-3 are all 0 (00000MMM)
                            -- OUT: port_addr bits 7-5 are 0, bits 4-3 can be non-zero (000RRMMM)
                            is_io_read <= (io_port_addr(7 downto 3) = "00000");
                            report "IO: PCC cycle detected, port=0x" & to_hstring(unsigned(io_port_addr)) &
                                   ", is_read=" & boolean'image(io_port_addr(7 downto 3) = "00000");
                        else
                            is_io_cycle <= false;
                        end if;
                    end if;
                    io_drive_bus <= '0';  -- Don't drive during T2

                -- T3 (S2S1S0 = 100): Data transfer
                -- For INP (read), drive the bus
                -- For OUT (write), tri-state the bus (CPU drives it)
                elsif S2_tb = '1' and S1_tb = '0' and S0_tb = '0' then
                    if is_io_cycle and is_io_read then
                        -- INP: Drive input data on bus
                        io_drive_bus <= '1';
                        report "IO T3: INP driving bus with 0x" & to_hstring(unsigned(io_bus_data));
                    else
                        -- OUT or non-I/O: Don't drive bus
                        io_drive_bus <= '0';
                    end if;

                -- Other states: Don't drive bus
                else
                    io_drive_bus <= '0';
                end if;
            end if;
        end if;
    end process;

    -- I/O input data generation (for INP instructions)
    io_input_data: process(io_port_addr)
    begin
        case io_port_addr(2 downto 0) is
            when "010" =>
                -- Port 2: Console RX Data - return 'H'
                io_bus_data <= console_input_data;
            when others =>
                io_bus_data <= x"00";
        end case;
    end process;

    -- Output capture and debug process
    output_capture: process(phi1_tb)
        variable current_state : std_logic_vector(2 downto 0);
        variable last_state : std_logic_vector(2 downto 0) := "000";
        variable cycle_type : std_logic_vector(1 downto 0) := "00";
    begin
        if rising_edge(phi1_tb) then
            current_state := S2_tb & S1_tb & S0_tb;

            -- Capture cycle type during T2
            if current_state = "010" and data_tb /= "ZZZZZZZZ" then
                cycle_type := data_tb(7 downto 6);
            end if;

            -- Detect rising edge of T3 during PCC (I/O) write cycle
            if current_state = "100" and last_state /= "100" and cycle_type = "10" then
                -- Capture output data
                if data_tb /= "ZZZZZZZZ" then
                    last_output <= data_tb;
                    report "OUT: 0x" & to_hstring(unsigned(data_tb));
                end if;
            end if;

            -- Debug: Show register A changes
            if debug_reg_A_tb /= x"00" then
                report "Reg A changed to: 0x" & to_hstring(unsigned(debug_reg_A_tb));
            end if;

            last_state := current_state;
        end if;
    end process;

    -- Test process
    test_proc: process
    begin
        report "========================================";
        report "Intel 8008 INP Instruction Unit Test";
        report "========================================";

        -- Reset
        reset_tb <= '1';
        reset_n_tb <= '0';
        wait for 20 us;
        reset_tb <= '0';
        wait for 5 us;
        reset_n_tb <= '1';

        report "Reset complete - starting test";
        report "I/O port 2 configured to provide: 0x48 ('H')";
        report "Test program: INP 2 -> OUT 8 -> HLT";

        -- Wait for program to complete
        wait for 100 us;

        report "========================================";
        report "Test Results:";
        report "========================================";
        report "Register A: 0x" & to_hstring(unsigned(debug_reg_A_tb));
        report "Output value: 0x" & to_hstring(unsigned(last_output));
        report "Final PC: 0x" & to_hstring(unsigned(debug_pc_tb));

        if last_output = x"48" and debug_reg_A_tb = x"48" then
            report "========================================";
            report "PASS: INP Instruction Test";
            report "  INP 2 correctly loaded 0x48 into register A";
            report "  OUT 8 correctly output register A (0x48)";
            report "========================================";
        elsif last_output /= x"48" then
            report "========================================";
            report "FAIL: INP Instruction Test";
            report "  Expected: INP 2 loads 0x48 into A, OUT 8 outputs 0x48";
            report "  Actual: Register A = 0x" & to_hstring(unsigned(debug_reg_A_tb)) &
                   ", Output = 0x" & to_hstring(unsigned(last_output));
            report "  INP instruction did not load I/O data into accumulator";
            report "========================================";
            assert false report "Test failed: INP did not load register A" severity failure;
        else
            report "========================================";
            report "FAIL: Unexpected test state";
            report "========================================";
            assert false report "Test failed: Unexpected state" severity failure;
        end if;

        test_complete <= true;
        wait;
    end process;

end sim;
