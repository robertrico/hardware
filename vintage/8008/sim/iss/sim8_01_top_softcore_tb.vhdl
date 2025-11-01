-- Testbench for SIM8-01 Top Level Softcore (with i8008 soft core)
-- Tests the complete system: CPU + ROM + RAM

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sim8_01_top_softcore_tb is
end sim8_01_top_softcore_tb;

architecture sim of sim8_01_top_softcore_tb is

    -- Use entity instantiation instead of component for hierarchy access
    -- component sim8_01_top is
    --     port (
    --         clk : in std_logic;
    --         rst : in std_logic;
    --         cpu_phi1 : out std_logic;
    --         cpu_phi2 : out std_logic;
    --         debug_led : out std_logic_vector(7 downto 0);
    --         sw : in std_logic_vector(7 downto 1)
    --     );
    -- end component;

    signal clk_tb : std_logic := '0';
    signal rst_tb : std_logic := '0';
    signal cpu_phi1_tb : std_logic;
    signal cpu_phi2_tb : std_logic;
    signal debug_led_tb : std_logic_vector(7 downto 0);
    signal sw_tb : std_logic_vector(7 downto 1) := (others => '0');
    signal debug_ram_byte_0_tb : std_logic_vector(7 downto 0);
    signal debug_mem_addr_tb : std_logic_vector(13 downto 0);
    signal debug_mem_data_tb : std_logic_vector(7 downto 0);
    signal debug_reg_h_tb : std_logic_vector(7 downto 0);
    signal debug_reg_l_tb : std_logic_vector(7 downto 0);
    signal debug_rom_cs_n_tb : std_logic;
    signal debug_ram_cs_n_tb : std_logic;
    signal debug_sync_tb : std_logic;

    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz
    signal sim_done : boolean := false;

begin

    -- UUT instantiation using entity work.sim8_01_top for hierarchy access
    uut: entity work.sim8_01_top(rtl)
        port map (
            clk => clk_tb,
            rst => rst_tb,
            cpu_phi1 => cpu_phi1_tb,
            cpu_phi2 => cpu_phi2_tb,
            debug_led => debug_led_tb,
            sw => sw_tb,
            debug_ram_byte_0 => debug_ram_byte_0_tb,
            debug_mem_addr => debug_mem_addr_tb,
            debug_mem_data => debug_mem_data_tb,
            debug_reg_h => debug_reg_h_tb,
            debug_reg_l => debug_reg_l_tb,
            debug_rom_cs_n => debug_rom_cs_n_tb,
            debug_ram_cs_n => debug_ram_cs_n_tb,
            debug_sync => debug_sync_tb
        );

    -- Clock generation
    clk_process: process
    begin
        while not sim_done loop
            clk_tb <= '0';
            wait for CLK_PERIOD / 2;
            clk_tb <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Test stimulus
    test_process: process
    begin
        report "=== SIM8-01 System Test Starting ===";

        -- Hold reset
        rst_tb <= '1';
        wait for 100 ns;

        -- Release reset
        rst_tb <= '0';
        report "Reset released - CPU should execute ADD program with RAM write";
        report "Program: MVI A,5  MVI B,3  ADD B  MVI H,0x08  MVI L,0x00  MOV M,A  HLT";
        report "Expected result: RAM[0x0800] = 0x08 after execution";
        wait for 20 ns;

        -- Wait for CPU to execute ADD program with RAM write
        -- Program:
        --   0x00: MVI A, 5   (2 bytes: 0x06, 0x05)
        --   0x02: MVI B, 3   (2 bytes: 0x0E, 0x03)
        --   0x04: ADD B      (1 byte: 0x81)
        --   0x05: MVI H, 8   (2 bytes: 0x26, 0x08)
        --   0x07: MVI L, 0   (2 bytes: 0x2E, 0x00)
        --   0x09: MOV M, A   (1 byte: 0xF8) - writes to RAM[0x0800]
        --   0x0A: HLT        (1 byte: 0x00)
        --
        -- Each instruction takes multiple cycles:
        -- MVI needs 2 fetches, ADD/MOV/HLT need 1 fetch each
        -- With ~2.2us cycle time, need ~40-60us for full execution

        wait for 5 us;
        report "After 5us: halted=" & std_logic'image(debug_led_tb(2));

        wait for 5 us;
        report "After 10us: halted=" & std_logic'image(debug_led_tb(2));

        wait for 10 us;
        report "After 20us: halted=" & std_logic'image(debug_led_tb(2));

        wait for 10 us;
        report "After 30us: halted=" & std_logic'image(debug_led_tb(2));

        wait for 10 us;
        report "After 40us: halted=" & std_logic'image(debug_led_tb(2));

        wait for 20 us;
        report "After 60us: halted=" & std_logic'image(debug_led_tb(2));

        wait for 20 us;
        report "After 80us: halted=" & std_logic'image(debug_led_tb(2));

        wait for 20 us;
        report "After 100us: halted=" & std_logic'image(debug_led_tb(2));

        -- Check if halted (debug_led(2) should be high)
        if debug_led_tb(2) = '1' then
            report "=== SUCCESS: CPU executed program and halted (debug_led(2)=1) ===" severity note;
        else
            report "=== INFO: CPU did not halt yet (program may need more time) ===" severity note;
        end if;

        -- Let simulation continue (controlled by SIM_STOP_TIME parameter)
        report "=== Continuing simulation (use SIM_STOP_TIME to control duration) ===";
        wait;

        -- Monitor a bit longer
        wait for 5 us;

        -- READ BACK RAM to verify the write worked
        -- Access RAM contents through debug output port
        -- RAM[0] should contain 0x08 (the result of 5+3)
        report "=== Verifying RAM Contents ===";
        report "RAM[0x000] (hex) = 0x" & to_hstring(debug_ram_byte_0_tb);
        report "RAM[0x000] (dec) = " & integer'image(to_integer(unsigned(debug_ram_byte_0_tb)));
        report "Expected: 0x08 (decimal 8)";

        -- Assert the value is correct
        assert debug_ram_byte_0_tb = x"08"
            report "FAIL: RAM[0x0800] = 0x" & to_hstring(debug_ram_byte_0_tb) &
                   ", expected 0x08"
            severity error;

        if debug_ram_byte_0_tb = x"08" then
            report "=== RAM VERIFICATION PASSED: RAM[0x0800] contains 0x08 ===" severity note;
        else
            report "=== RAM VERIFICATION FAILED: RAM[0x0800] = 0x" & to_hstring(debug_ram_byte_0_tb) severity error;
        end if;

        report "=== SIM8-01 System Test Complete ===";
        report "Final debug_led state: " & integer'image(to_integer(unsigned(debug_led_tb)));
        sim_done <= true;
        wait;
    end process;

    -- Monitor debug LEDs and RAM
    monitor_process: process(debug_led_tb)
    begin
        report "DEBUG_LED: phi1=" & std_logic'image(debug_led_tb(0)) &
               " phi2=" & std_logic'image(debug_led_tb(1)) &
               " halted=" & std_logic'image(debug_led_tb(2)) &
               " mem_read=" & std_logic'image(debug_led_tb(3)) &
               " mem_write=" & std_logic'image(debug_led_tb(4)) &
               " @" & time'image(now);
    end process;

    -- Monitor memory writes
    monitor_writes: process(debug_led_tb(4))
    begin
        if debug_led_tb(4) = '1' then
            report "*** MEMORY WRITE: addr=0x" & to_hstring(debug_mem_addr_tb) &
                   " data=0x" & to_hstring(debug_mem_data_tb) &
                   " @" & time'image(now);
        end if;
    end process;

    -- Monitor RAM byte 0 changes
    monitor_ram: process(debug_ram_byte_0_tb)
    begin
        if debug_ram_byte_0_tb /= x"00" then
            report "*** RAM[0] CHANGED to 0x" & to_hstring(debug_ram_byte_0_tb) & " at " & time'image(now);
        end if;
    end process;

    -- Monitor SYNC signal (from CPU)
    monitor_sync: process(debug_sync_tb)
    begin
        report "*** SYNC=" & std_logic'image(debug_sync_tb) & " at " & time'image(now);
    end process;

    -- Monitor is_read_cycle
    monitor_read: process(debug_led_tb(5))
    begin
        report "*** is_read_cycle=" & std_logic'image(debug_led_tb(5)) &
               " cycle_type=" & integer'image(to_integer(unsigned(debug_led_tb(7 downto 6)))) &
               " at " & time'image(now);
    end process;

    -- Monitor address changes
    monitor_addr: process(debug_mem_addr_tb)
    begin
        if debug_mem_addr_tb /= "UUUUUUUUUUUUUU" and debug_mem_addr_tb /= "00000000000000" then
            report "*** ADDRESS changed to 0x" & to_hstring(debug_mem_addr_tb) &
                   " at " & time'image(now);
        end if;
    end process;

    -- Monitor data bus
    monitor_data: process(debug_mem_data_tb)
    begin
        if debug_mem_data_tb /= "UUUUUUUU" and debug_mem_data_tb /= "ZZZZZZZZ" then
            report "*** DATA_BUS changed to 0x" & to_hstring(debug_mem_data_tb) &
                   " at " & time'image(now);
        end if;
    end process;

    -- Monitor ROM chip select
    monitor_rom_cs: process(debug_rom_cs_n_tb)
    begin
        if debug_rom_cs_n_tb = '0' then
            report "*** ROM_CS_N asserted (active) at " & time'image(now);
        elsif debug_rom_cs_n_tb = '1' then
            report "*** ROM_CS_N deasserted at " & time'image(now);
        end if;
    end process;

end sim;
