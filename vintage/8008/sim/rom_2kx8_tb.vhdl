library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rom_2kx8_tb is
end rom_2kx8_tb;

architecture sim of rom_2kx8_tb is
    -- Component declaration
    component rom_2kx8 is
        port (
            ADDR : in std_logic_vector(10 downto 0);
            DATA_OUT : out std_logic_vector(7 downto 0);
            CS_N : in std_logic
        );
    end component;

    signal sim_done : boolean := false;

    -- Test signals
    signal ADDR_tb : std_logic_vector(10 downto 0) := (others => '0');
    signal DATA_OUT_tb : std_logic_vector(7 downto 0);
    signal CS_N_tb : std_logic := '1';

begin
    -- Device Under Test
    dut : rom_2kx8
        port map (
            ADDR => ADDR_tb,
            DATA_OUT => DATA_OUT_tb,
            CS_N => CS_N_tb
        );

    -- Main stimulus process
    test_process: process
    begin
        wait for 20 ns;

        -- Test 1: CS_N high (disabled) - should output Z
        report "Test 1: CS_N=1 (disabled) -> expect Z on output";
        ADDR_tb <= "00000000000";
        CS_N_tb <= '1';
        wait for 20 ns;
        assert DATA_OUT_tb = "ZZZZZZZZ" report "FAIL: Expected Z when disabled" severity error;

        -- Test 2: CS_N low, read address 0
        report "Test 2: CS_N=0, ADDR=0 -> expect 0x00";
        ADDR_tb <= "00000000000";
        CS_N_tb <= '0';
        wait for 20 ns;
        assert DATA_OUT_tb = x"00" report "FAIL: Expected 0x00 at address 0" severity error;

        -- Test 3: Read address 1
        report "Test 3: CS_N=0, ADDR=1 -> expect 0x01";
        ADDR_tb <= "00000000001";
        wait for 20 ns;
        assert DATA_OUT_tb = x"01" report "FAIL: Expected 0x01 at address 1" severity error;

        -- Test 4: Read address 2
        report "Test 4: CS_N=0, ADDR=2 -> expect 0x02";
        ADDR_tb <= "00000000010";
        wait for 20 ns;
        assert DATA_OUT_tb = x"02" report "FAIL: Expected 0x02 at address 2" severity error;

        -- Test 5: Read uninitialized address (should be 0xFF)
        report "Test 5: CS_N=0, ADDR=100 -> expect 0xFF (default)";
        ADDR_tb <= "00001100100";  -- 100 in binary
        wait for 20 ns;
        assert DATA_OUT_tb = x"FF" report "FAIL: Expected 0xFF at uninitialized address" severity error;

        -- Test 6: Read max address (2047)
        report "Test 6: CS_N=0, ADDR=2047 -> expect 0xFF";
        ADDR_tb <= "11111111111";  -- 2047 in binary
        wait for 20 ns;
        assert DATA_OUT_tb = x"FF" report "FAIL: Expected 0xFF at max address" severity error;

        -- Test 7: Disable CS_N again
        report "Test 7: CS_N=1 (disabled) -> expect Z";
        CS_N_tb <= '1';
        wait for 20 ns;
        assert DATA_OUT_tb = "ZZZZZZZZ" report "FAIL: Expected Z when disabled" severity error;

        -- Test 8: Re-enable and verify address 0 again
        report "Test 8: Re-enable, ADDR=0 -> expect 0x00";
        ADDR_tb <= "00000000000";
        CS_N_tb <= '0';
        wait for 20 ns;
        assert DATA_OUT_tb = x"00" report "FAIL: Expected 0x00 at address 0" severity error;

        -- End simulation
        report "=== ROM 2Kx8 Test Complete ===";
        sim_done <= true;
        wait;
    end process;
end sim;
