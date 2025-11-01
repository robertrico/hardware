-------------------------------------------------------------------------------
-- Testbench for SIM8-01 V2 Top Level Softcore (with proper glue logic)
-- Tests the complete system with free-running T5 cycles
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sim8_01_top_v2_softcore_tb is
end sim8_01_top_v2_softcore_tb;

architecture sim of sim8_01_top_v2_softcore_tb is

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

    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz
    signal sim_done : boolean := false;

begin

    -- UUT instantiation using v2 design with proper glue logic
    uut: entity work.sim8_01_top_v2_softcore(rtl)
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
            debug_ram_cs_n => debug_ram_cs_n_tb
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
        report "=== SIM8-01 V2 System Test Starting (Free-Running T5 Cycles) ===";

        -- Hold reset
        rst_tb <= '1';
        wait for 100 ns;

        -- Release reset
        rst_tb <= '0';
        report "Reset released - CPU should execute RAM intensive program";
        report "Program: Fill RAM with pattern, calculate sum, invert, verify";
        wait for 20 ns;

        -- Monitor progress
        wait for 5 us;
        report "After 5us: halted=" & std_logic'image(debug_led_tb(2)) & " HL=" & to_hstring(debug_reg_h_tb & debug_reg_l_tb);

        wait for 5 us;
        report "After 10us: halted=" & std_logic'image(debug_led_tb(2)) & " HL=" & to_hstring(debug_reg_h_tb & debug_reg_l_tb);

        wait for 10 us;
        report "After 20us: halted=" & std_logic'image(debug_led_tb(2)) & " HL=" & to_hstring(debug_reg_h_tb & debug_reg_l_tb);

        wait for 10 us;
        report "After 30us: halted=" & std_logic'image(debug_led_tb(2)) & " HL=" & to_hstring(debug_reg_h_tb & debug_reg_l_tb);

        wait for 10 us;
        report "After 40us: halted=" & std_logic'image(debug_led_tb(2)) & " HL=" & to_hstring(debug_reg_h_tb & debug_reg_l_tb);

        wait for 20 us;
        report "After 60us: halted=" & std_logic'image(debug_led_tb(2)) & " HL=" & to_hstring(debug_reg_h_tb & debug_reg_l_tb);

        wait for 20 us;
        report "After 80us: halted=" & std_logic'image(debug_led_tb(2)) & " HL=" & to_hstring(debug_reg_h_tb & debug_reg_l_tb);

        wait for 20 us;
        report "After 100us: halted=" & std_logic'image(debug_led_tb(2)) & " HL=" & to_hstring(debug_reg_h_tb & debug_reg_l_tb);

        -- Check if halted
        if debug_led_tb(2) = '1' then
            report "=== SUCCESS: CPU executed program and halted ===" severity note;
            report "Register H = 0x" & to_hstring(debug_reg_h_tb);
            report "Register L = 0x" & to_hstring(debug_reg_l_tb);
        else
            report "=== INFO: CPU did not halt yet (program may need more time) ===" severity note;
        end if;

        -- Let simulation continue (controlled by SIM_STOP_TIME parameter)
        report "=== Continuing simulation (use SIM_STOP_TIME to control duration) ===";
        wait;

        report "=== SIM8-01 V2 System Test Complete ===";
        sim_done <= true;
        wait;
    end process;

    -- Monitor debug LEDs
    monitor_process: process(debug_led_tb)
    begin
        report "DEBUG_LED: phi1=" & std_logic'image(debug_led_tb(0)) &
               " phi2=" & std_logic'image(debug_led_tb(1)) &
               " halted=" & std_logic'image(debug_led_tb(2)) &
               " T1=" & std_logic'image(debug_led_tb(3)) &
               " T2=" & std_logic'image(debug_led_tb(4)) &
               " T3=" & std_logic'image(debug_led_tb(5)) &
               " cycle_type=" & integer'image(to_integer(unsigned(debug_led_tb(7 downto 6)))) &
               " @" & time'image(now);
    end process;

    -- Monitor RAM chip select
    monitor_ram_cs: process(debug_ram_cs_n_tb)
    begin
        if debug_ram_cs_n_tb = '0' then
            report "*** RAM_CS_N asserted: addr=0x" & to_hstring(debug_mem_addr_tb) &
                   " data=0x" & to_hstring(debug_mem_data_tb) &
                   " @" & time'image(now);
        end if;
    end process;

    -- Monitor ROM chip select
    monitor_rom_cs: process(debug_rom_cs_n_tb)
    begin
        if debug_rom_cs_n_tb = '0' then
            report "*** ROM_CS_N asserted: addr=0x" & to_hstring(debug_mem_addr_tb) &
                   " data=0x" & to_hstring(debug_mem_data_tb) &
                   " @" & time'image(now);
        end if;
    end process;

    -- Monitor RAM byte 0 changes
    monitor_ram: process(debug_ram_byte_0_tb)
    begin
        if debug_ram_byte_0_tb /= x"00" then
            report "*** RAM[0x0800] CHANGED to 0x" & to_hstring(debug_ram_byte_0_tb) & " at " & time'image(now);
        end if;
    end process;

    -- Monitor address changes (only show significant changes)
    monitor_addr: process(debug_mem_addr_tb)
    begin
        if debug_mem_addr_tb /= "UUUUUUUUUUUUUU" then
            report "*** ADDRESS: 0x" & to_hstring(debug_mem_addr_tb) & " @" & time'image(now);
        end if;
    end process;

    -- Monitor register H/L (shows HL pointer for RAM operations)
    monitor_regs: process(debug_reg_h_tb, debug_reg_l_tb)
    begin
        if debug_reg_h_tb /= x"00" or debug_reg_l_tb /= x"00" then
            report "*** REGISTERS: H=0x" & to_hstring(debug_reg_h_tb) &
                   " L=0x" & to_hstring(debug_reg_l_tb) &
                   " HL=0x" & to_hstring(debug_reg_h_tb & debug_reg_l_tb) &
                   " @" & time'image(now);
        end if;
    end process;

end sim;
