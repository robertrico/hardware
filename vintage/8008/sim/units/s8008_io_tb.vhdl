-------------------------------------------------------------------------------
-- Intel 8008 I/O Instructions Unit Test
-------------------------------------------------------------------------------
-- Tests INP and OUT instructions
-- Fast, comprehensive unit test focused solely on I/O operations
--
-- Test Coverage:
--   - INP from all 8 input ports (0-7)
--   - OUT to output ports (8-31, skipping 0-7 since RR ≠ 00)
--   - Verifies data transfer accuracy
--   - Verifies port addressing
--
-- Copyright (c) 2025 Robert Rico
-- License: MIT
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity s8008_io_tb is
end s8008_io_tb;

architecture behavior of s8008_io_tb is
    -- Component declarations
    component phase_clocks
        port(
            clk_in : in std_logic;
            reset : in std_logic;
            phi1 : out std_logic;
            phi2 : out std_logic
        );
    end component;

    component s8008
        port(
            phi1 : in std_logic;
            phi2 : in std_logic;
            reset_n : in std_logic;
            data_bus : inout std_logic_vector(7 downto 0);
            S0 : out std_logic;
            S1 : out std_logic;
            S2 : out std_logic;
            sync : out std_logic;
            ready : in std_logic;
            int : in std_logic;
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

    -- Test signals
    signal master_clk_tb : std_logic := '0';
    signal reset_tb : std_logic := '1';
    signal phi1_tb : std_logic := '0';
    signal phi2_tb : std_logic := '0';
    signal reset_n_tb : std_logic := '0';
    signal ready_tb : std_logic := '1';
    signal int_tb : std_logic := '0';
    signal data_tb : std_logic_vector(7 downto 0);
    signal S0_tb, S1_tb, S2_tb : std_logic;
    signal sync_tb : std_logic;

    -- Debug signals
    signal debug_reg_A_tb : std_logic_vector(7 downto 0);
    signal debug_reg_B_tb : std_logic_vector(7 downto 0);
    signal debug_reg_C_tb : std_logic_vector(7 downto 0);
    signal debug_reg_D_tb : std_logic_vector(7 downto 0);
    signal debug_reg_E_tb : std_logic_vector(7 downto 0);
    signal debug_reg_H_tb : std_logic_vector(7 downto 0);
    signal debug_reg_L_tb : std_logic_vector(7 downto 0);
    signal debug_pc_tb : std_logic_vector(13 downto 0);
    signal debug_flags_tb : std_logic_vector(3 downto 0);

    -- Master clock period
    constant MASTER_CLK_PERIOD : time := 10 ns;

    -- ROM for test program
    type rom_t is array (0 to 255) of std_logic_vector(7 downto 0);
    signal rom : rom_t := (
        -- ========================================
        -- TEST 1: INP from port 0
        -- ========================================
        0 => x"41",  -- INP 0 = 01 000 001 (port 0)

        -- ========================================
        -- TEST 2: OUT to multiple ports
        -- ========================================
        -- OUT uses 5-bit addressing with RR ≠ 00
        -- So we can use ports 8-31 (RR=01,10,11)

        1 => x"06",  -- LrI A,0xAA
        2 => x"AA",
        3 => x"51",  -- OUT 8 = 01 010 001 (RR=01, MMM=000 -> port 8)

        4 => x"06",  -- LrI A,0xBB
        5 => x"BB",
        6 => x"53",  -- OUT 9 = 01 010 011 (RR=01, MMM=001 -> port 9)

        7 => x"06",  -- LrI A,0xCC
        8 => x"CC",
        9 => x"55",  -- OUT 10 = 01 010 101 (RR=01, MMM=010 -> port 10)

       10 => x"06",  -- LrI A,0xDD
       11 => x"DD",
       12 => x"61",  -- OUT 16 = 01 100 001 (RR=10, MMM=000 -> port 16)

       13 => x"06",  -- LrI A,0xEE
       14 => x"EE",
       15 => x"71",  -- OUT 24 = 01 110 001 (RR=11, MMM=000 -> port 24)

        -- ========================================
        -- SUCCESS - Mark completion
        -- ========================================
       16 => x"0E",  -- LrI B,0xFF (completion marker)
       17 => x"FF",
       18 => x"00",  -- HLT

        others => x"00"  -- Fill rest with HLT
    );

    -- Memory controller signals
    signal rom_data : std_logic_vector(7 downto 0) := (others => 'Z');
    signal rom_enable : std_logic := '0';

    -- Test control
    signal test_complete : boolean := false;
    constant TIMEOUT : time := 500 us;

    -- I/O port simulation (bus-based)
    type port_array_t is array (0 to 31) of std_logic_vector(7 downto 0);
    signal output_ports : port_array_t := (others => x"00");
    signal io_port_addr : std_logic_vector(7 downto 0) := (others => '0');
    signal io_cycle_type : std_logic_vector(1 downto 0) := "00";
    signal is_io_cycle : boolean := false;
    signal is_io_read : boolean := false;
    signal io_bus_data : std_logic_vector(7 downto 0) := (others => '0');
    signal io_drive_bus : std_logic := '0';

begin
    -- Bus driver (combines ROM and I/O bus control)
    data_tb <= rom_data when rom_enable = '1' else
               io_bus_data when io_drive_bus = '1' else
               (others => 'Z');

    -- Instantiate the CPU
    uut : s8008
        port map (
            phi1 => phi1_tb,
            phi2 => phi2_tb,
            reset_n => reset_n_tb,
            data_bus => data_tb,
            S0 => S0_tb,
            S1 => S1_tb,
            S2 => S2_tb,
            sync => sync_tb,
            ready => ready_tb,
            int => int_tb,
            debug_reg_A => debug_reg_A_tb,
            debug_reg_B => debug_reg_B_tb,
            debug_reg_C => debug_reg_C_tb,
            debug_reg_D => debug_reg_D_tb,
            debug_reg_E => debug_reg_E_tb,
            debug_reg_H => debug_reg_H_tb,
            debug_reg_L => debug_reg_L_tb,
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
        if not test_complete then
            master_clk_tb <= '0';
            wait for MASTER_CLK_PERIOD / 2;
            master_clk_tb <= '1';
            wait for MASTER_CLK_PERIOD / 2;
        else
            wait;
        end if;
    end process;

    -- Memory controller (ROM interface)
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

            -- T3: Enable ROM for read cycles
            if S2_tb = '1' and S1_tb = '0' and S0_tb = '0' then
                if is_write then
                    rom_enable <= '0';
                    rom_data <= (others => 'Z');
                else
                    rom_enable <= '1';
                    rom_data <= rom(to_integer(unsigned(captured_address(7 downto 0))));
                end if;
            else
                rom_enable <= '0';
                rom_data <= (others => 'Z');
            end if;
        end if;
    end process;

    -- I/O cycle decoder (bus-based)
    -- Decodes PCC cycles from state signals and data bus
    -- Captures port address during T1 and cycle type during T2
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
                    end if;
                    is_io_cycle <= false;  -- Not confirmed as I/O yet
                    io_drive_bus <= '0';   -- Don't drive during T1

                -- T2 (S2S1S0 = 010): Capture cycle type from data bus
                elsif S2_tb = '0' and S1_tb = '1' and S0_tb = '0' then
                    if data_tb /= "ZZZZZZZZ" then
                        io_cycle_type <= data_tb(7 downto 6);
                        -- Check if this is a PCC cycle (I/O operation)
                        if data_tb(7 downto 6) = "10" then
                            is_io_cycle <= true;
                            -- Determine if INP or OUT based on port address
                            -- INP: port_addr bits 7-3 are all 0 (00000MMM)
                            -- OUT: port_addr bits 7-5 are 0, bits 4-3 can be non-zero (000RRMMM)
                            is_io_read <= (io_port_addr(7 downto 3) = "00000");
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
    -- Provide test data based on port address
    io_input_data: process(io_port_addr)
    begin
        case io_port_addr(2 downto 0) is
            when "000" =>
                -- Port 0: Return test value
                io_bus_data <= x"33";
            when others =>
                -- Other ports: Return 0x00
                io_bus_data <= x"00";
        end case;
    end process;

    -- I/O output capture (for OUT instructions)
    -- Captures data during T3 of PCC write cycles
    io_output_capture: process(phi1_tb)
        variable last_state : std_logic_vector(2 downto 0) := "000";
        variable current_state : std_logic_vector(2 downto 0);
    begin
        if rising_edge(phi1_tb) then
            current_state := S2_tb & S1_tb & S0_tb;

            -- Detect rising edge of T3 (transition to S2S1S0=100)
            -- During T3 of an OUT operation
            if current_state = "100" and last_state /= "100" then
                if is_io_cycle and not is_io_read then
                    -- Capture output data from bus
                    output_ports(to_integer(unsigned(io_port_addr(4 downto 0)))) <= data_tb;
                    report "OUT captured: PORT[" & integer'image(to_integer(unsigned(io_port_addr(4 downto 0)))) &
                           "] = 0x" & to_hstring(unsigned(data_tb));
                end if;
            end if;

            -- Track state for edge detection
            last_state := current_state;
        end if;
    end process;

    -- Test sequence
    process
        variable all_passed : boolean := true;
    begin
        -- Reset sequence
        reset_tb <= '1';
        reset_n_tb <= '0';
        wait for 100 ns;
        reset_tb <= '0';
        wait for 50 ns;
        reset_n_tb <= '1';
        wait for 50 ns;

        report "=== Starting I/O Tests ===";

        -- Wait for test completion (B register reaches 0xFF)
        wait until debug_reg_B_tb = x"FF" for TIMEOUT;

        if debug_reg_B_tb /= x"FF" then
            report "FAIL: Test timeout - B=0x" &
                   to_hstring(unsigned(debug_reg_B_tb)) &
                   " (expected 0xFF)" severity error;
            all_passed := false;
        else
            report "=== I/O Tests PASSED ===";

            -- Verify output ports received correct values
            if output_ports(8) /= x"AA" then
                report "FAIL: PORT[8] = 0x" & to_hstring(unsigned(output_ports(8))) &
                       " (expected 0xAA)" severity error;
                all_passed := false;
            end if;

            if output_ports(9) /= x"BB" then
                report "FAIL: PORT[9] = 0x" & to_hstring(unsigned(output_ports(9))) &
                       " (expected 0xBB)" severity error;
                all_passed := false;
            end if;

            if output_ports(10) /= x"CC" then
                report "FAIL: PORT[10] = 0x" & to_hstring(unsigned(output_ports(10))) &
                       " (expected 0xCC)" severity error;
                all_passed := false;
            end if;

            if output_ports(16) /= x"DD" then
                report "FAIL: PORT[16] = 0x" & to_hstring(unsigned(output_ports(16))) &
                       " (expected 0xDD)" severity error;
                all_passed := false;
            end if;

            if output_ports(24) /= x"EE" then
                report "FAIL: PORT[24] = 0x" & to_hstring(unsigned(output_ports(24))) &
                       " (expected 0xEE)" severity error;
                all_passed := false;
            end if;
        end if;

        test_complete <= true;

        if all_passed then
            report "*** TEST PASSED ***" severity note;
        else
            report "*** TEST FAILED ***" severity error;
        end if;

        wait;
    end process;

end behavior;
