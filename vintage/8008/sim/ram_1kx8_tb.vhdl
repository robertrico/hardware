library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ram_1kx8_tb is
end ram_1kx8_tb;

architecture sim of ram_1kx8_tb is
    -- Component declaration
    component ram_1kx8 is
        port (
            ADDR : in std_logic_vector(9 downto 0);
            DATA_IN : in std_logic_vector(7 downto 0);
            DATA_OUT : out std_logic_vector(7 downto 0);
            RW_N : in std_logic;
            CS_N : in std_logic
        );
    end component;

    signal sim_done : boolean := false;

    -- Test signals
    signal ADDR_tb : std_logic_vector(9 downto 0) := (others => '0');
    signal DATA_IN_tb : std_logic_vector(7 downto 0) := (others => '0');
    signal DATA_OUT_tb : std_logic_vector(7 downto 0);
    signal RW_N_tb : std_logic := '1';
    signal CS_N_tb : std_logic := '1';

begin
    -- Device Under Test
    dut : ram_1kx8
        port map (
            ADDR => ADDR_tb,
            DATA_IN => DATA_IN_tb,
            DATA_OUT => DATA_OUT_tb,
            RW_N => RW_N_tb,
            CS_N => CS_N_tb
        );

    -- Main stimulus process
    test_process: process
    begin
        wait for 20 ns;

        -- Test 1: CS_N high (disabled) - should output Z
        report "Test 1: CS_N=1 (disabled) -> expect Z on output";
        ADDR_tb <= "0000000000";
        CS_N_tb <= '1';
        RW_N_tb <= '1';
        wait for 20 ns;
        assert DATA_OUT_tb = "ZZZZZZZZ" report "FAIL: Expected Z when disabled" severity error;

        -- Test 2: Read address 0 (should be initialized to 0x00)
        report "Test 2: Read ADDR=0 -> expect 0x00 (initial)";
        ADDR_tb <= "0000000000";
        CS_N_tb <= '0';
        RW_N_tb <= '1';  -- Read mode
        wait for 20 ns;
        assert DATA_OUT_tb = x"00" report "FAIL: Expected 0x00 at unwritten address" severity error;

        -- Test 3: Write 0xAA to address 0
        report "Test 3: Write 0xAA to ADDR=0";
        ADDR_tb <= "0000000000";
        DATA_IN_tb <= x"AA";
        RW_N_tb <= '0';  -- Write mode
        wait for 20 ns;

        -- Test 4: Read back address 0
        report "Test 4: Read ADDR=0 -> expect 0xAA";
        RW_N_tb <= '1';  -- Read mode
        wait for 20 ns;
        assert DATA_OUT_tb = x"AA" report "FAIL: Expected 0xAA after write" severity error;

        -- Test 5: Write 0x55 to address 1
        report "Test 5: Write 0x55 to ADDR=1";
        ADDR_tb <= "0000000001";
        DATA_IN_tb <= x"55";
        RW_N_tb <= '0';  -- Write mode
        wait for 20 ns;

        -- Test 6: Read back address 1
        report "Test 6: Read ADDR=1 -> expect 0x55";
        RW_N_tb <= '1';  -- Read mode
        wait for 20 ns;
        assert DATA_OUT_tb = x"55" report "FAIL: Expected 0x55 after write" severity error;

        -- Test 7: Verify address 0 still has 0xAA
        report "Test 7: Read ADDR=0 -> expect 0xAA (unchanged)";
        ADDR_tb <= "0000000000";
        wait for 20 ns;
        assert DATA_OUT_tb = x"AA" report "FAIL: Expected 0xAA still at address 0" severity error;

        -- Test 8: Write to max address (1023)
        report "Test 8: Write 0xFF to ADDR=1023";
        ADDR_tb <= "1111111111";  -- 1023
        DATA_IN_tb <= x"FF";
        RW_N_tb <= '0';  -- Write mode
        wait for 20 ns;

        -- Test 9: Read back max address
        report "Test 9: Read ADDR=1023 -> expect 0xFF";
        RW_N_tb <= '1';  -- Read mode
        wait for 20 ns;
        assert DATA_OUT_tb = x"FF" report "FAIL: Expected 0xFF at max address" severity error;

        -- Test 10: Disable chip and verify tri-state
        report "Test 10: CS_N=1 (disabled) -> expect Z";
        CS_N_tb <= '1';
        wait for 20 ns;
        assert DATA_OUT_tb = "ZZZZZZZZ" report "FAIL: Expected Z when disabled" severity error;

        -- Test 11: Write multiple addresses
        report "Test 11: Sequential write test";
        CS_N_tb <= '0';
        RW_N_tb <= '0';  -- Write mode
        for i in 10 to 15 loop
            ADDR_tb <= std_logic_vector(to_unsigned(i, 10));
            DATA_IN_tb <= std_logic_vector(to_unsigned(i * 2, 8));
            wait for 20 ns;
        end loop;

        -- Test 12: Read back and verify
        report "Test 12: Sequential read verification";
        RW_N_tb <= '1';  -- Read mode
        for i in 10 to 15 loop
            ADDR_tb <= std_logic_vector(to_unsigned(i, 10));
            wait for 20 ns;
            assert DATA_OUT_tb = std_logic_vector(to_unsigned(i * 2, 8))
                report "FAIL: Sequential read mismatch at address " & integer'image(i) severity error;
        end loop;

        -- End simulation
        report "=== RAM 1Kx8 Test Complete ===";
        sim_done <= true;
        wait;
    end process;
end sim;
