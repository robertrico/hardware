library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ic3404_tb is
end ic3404_tb;

architecture sim of ic3404_tb is
    -- Component declaration
    component ic3404 is
        port (
            D : in std_logic_vector(5 downto 0);
            W1 : in std_logic;
            W2 : in std_logic;
            O : out std_logic_vector(5 downto 0)
        );
    end component;

    signal sim_done : boolean := false;

    -- Test signals
    signal D_tb : std_logic_vector(5 downto 0) := "000000";
    signal W1_tb : std_logic := '0';
    signal W2_tb : std_logic := '0';
    signal O_tb : std_logic_vector(5 downto 0);

begin
    -- Device Under Test
    dut : ic3404
        port map (
            D => D_tb,
            W1 => W1_tb,
            W2 => W2_tb,
            O => O_tb
        );

    -- Main stimulus process
    test_process: process
    begin
        wait for 20 ns;

        -- ===================================================================
        -- Test 4-bit latch (W1 controls D0-D3 -> O0-O3)
        -- ===================================================================
        report "=== Testing 4-bit latch (W1 controls D0-D3) ===";

        -- Test 1: W1=H, data should pass through (transparent mode)
        report "Test 1: W1=H, D(3:0)=1010 -> O(3:0) should be 1010 (transparent)";
        D_tb <= "001010";  -- D5-D0 = 001010
        W1_tb <= '1';
        W2_tb <= '0';
        wait for 20 ns;
        assert O_tb(3 downto 0) = "1010" report "FAIL: Expected O(3:0)=1010, got " & integer'image(to_integer(unsigned(O_tb(3 downto 0)))) severity error;

        -- Test 2: Change data while W1=H, output should follow
        report "Test 2: W1=H, D(3:0)=0101 -> O(3:0) should be 0101 (still transparent)";
        D_tb(3 downto 0) <= "0101";
        wait for 20 ns;
        assert O_tb(3 downto 0) = "0101" report "FAIL: Expected O(3:0)=0101, got " & integer'image(to_integer(unsigned(O_tb(3 downto 0)))) severity error;

        -- Test 3: W1=L, output should hold last value
        report "Test 3: W1=L, D(3:0)=1111 -> O(3:0) should stay 0101 (latched)";
        W1_tb <= '0';
        wait for 10 ns;
        D_tb(3 downto 0) <= "1111";
        wait for 20 ns;
        assert O_tb(3 downto 0) = "0101" report "FAIL: Expected O(3:0)=0101 (held), got " & integer'image(to_integer(unsigned(O_tb(3 downto 0)))) severity error;

        -- Test 4: Change data multiple times while W1=L, output stays same
        report "Test 4: W1=L, D(3:0) changes -> O(3:0) should stay 0101 (held)";
        D_tb(3 downto 0) <= "0000";
        wait for 20 ns;
        assert O_tb(3 downto 0) = "0101" report "FAIL: Expected O(3:0)=0101 (held), got " & integer'image(to_integer(unsigned(O_tb(3 downto 0)))) severity error;

        -- Test 5: Re-enable W1, new data passes through
        report "Test 5: W1=H, D(3:0)=1100 -> O(3:0) should be 1100 (transparent again)";
        D_tb(3 downto 0) <= "1100";
        W1_tb <= '1';
        wait for 20 ns;
        assert O_tb(3 downto 0) = "1100" report "FAIL: Expected O(3:0)=1100, got " & integer'image(to_integer(unsigned(O_tb(3 downto 0)))) severity error;

        -- ===================================================================
        -- Test 2-bit latch (W2 controls D4-D5 -> O4-O5)
        -- ===================================================================
        report "=== Testing 2-bit latch (W2 controls D4-D5) ===";

        -- Test 6: W2=H, data should pass through
        report "Test 6: W2=H, D(5:4)=10 -> O(5:4) should be 10 (transparent)";
        D_tb(5 downto 4) <= "10";
        W1_tb <= '0';
        W2_tb <= '1';
        wait for 20 ns;
        assert O_tb(5 downto 4) = "10" report "FAIL: Expected O(5:4)=10, got " & integer'image(to_integer(unsigned(O_tb(5 downto 4)))) severity error;

        -- Test 7: Change data while W2=H, output follows
        report "Test 7: W2=H, D(5:4)=01 -> O(5:4) should be 01 (still transparent)";
        D_tb(5 downto 4) <= "01";
        wait for 20 ns;
        assert O_tb(5 downto 4) = "01" report "FAIL: Expected O(5:4)=01, got " & integer'image(to_integer(unsigned(O_tb(5 downto 4)))) severity error;

        -- Test 8: W2=L, output holds
        report "Test 8: W2=L, D(5:4)=11 -> O(5:4) should stay 01 (latched)";
        W2_tb <= '0';
        wait for 10 ns;
        D_tb(5 downto 4) <= "11";
        wait for 20 ns;
        assert O_tb(5 downto 4) = "01" report "FAIL: Expected O(5:4)=01 (held), got " & integer'image(to_integer(unsigned(O_tb(5 downto 4)))) severity error;

        -- Test 9: Change data while W2=L, output stays same
        report "Test 9: W2=L, D(5:4)=00 -> O(5:4) should stay 01 (held)";
        D_tb(5 downto 4) <= "00";
        wait for 20 ns;
        assert O_tb(5 downto 4) = "01" report "FAIL: Expected O(5:4)=01 (held), got " & integer'image(to_integer(unsigned(O_tb(5 downto 4)))) severity error;

        -- ===================================================================
        -- Test both latches independently
        -- ===================================================================
        report "=== Testing independent operation of both latches ===";

        -- Test 10: Enable W1 only, 4-bit changes, 2-bit stays held
        report "Test 10: W1=H, W2=L, change D(3:0) -> only O(3:0) changes";
        D_tb <= "110011";  -- D5-D0
        W1_tb <= '1';
        W2_tb <= '0';
        wait for 20 ns;
        assert O_tb(3 downto 0) = "0011" report "FAIL: Expected O(3:0)=0011, got " & integer'image(to_integer(unsigned(O_tb(3 downto 0)))) severity error;
        assert O_tb(5 downto 4) = "01" report "FAIL: Expected O(5:4)=01 (held from before), got " & integer'image(to_integer(unsigned(O_tb(5 downto 4)))) severity error;

        -- Test 11: Enable W2 only, 2-bit changes, 4-bit stays held
        report "Test 11: W1=L, W2=H, change D(5:4) -> only O(5:4) changes";
        D_tb <= "101111";  -- D5-D0
        W1_tb <= '0';
        W2_tb <= '1';
        wait for 20 ns;
        assert O_tb(3 downto 0) = "0011" report "FAIL: Expected O(3:0)=0011 (held from before), got " & integer'image(to_integer(unsigned(O_tb(3 downto 0)))) severity error;
        assert O_tb(5 downto 4) = "10" report "FAIL: Expected O(5:4)=10, got " & integer'image(to_integer(unsigned(O_tb(5 downto 4)))) severity error;

        -- Test 12: Enable both W1 and W2, all 6 bits transparent
        report "Test 12: W1=H, W2=H, D=111000 -> O should be 111000 (all transparent)";
        D_tb <= "111000";
        W1_tb <= '1';
        W2_tb <= '1';
        wait for 20 ns;
        assert O_tb = "111000" report "FAIL: Expected O=111000, got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- Test 13: Disable both W1 and W2, all bits hold
        report "Test 13: W1=L, W2=L, D=000111 -> O should stay 111000 (all held)";
        W1_tb <= '0';
        W2_tb <= '0';
        wait for 10 ns;
        D_tb <= "000111";
        wait for 20 ns;
        assert O_tb = "111000" report "FAIL: Expected O=111000 (all held), got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- Test 14: Complex sequence - latch different values at different times
        report "Test 14: Complex sequence test";
        -- Set 4-bit to 1010
        D_tb(3 downto 0) <= "1010";
        W1_tb <= '1';
        W2_tb <= '0';
        wait for 20 ns;
        W1_tb <= '0';  -- Latch it
        wait for 10 ns;

        -- Set 2-bit to 11
        D_tb(5 downto 4) <= "11";
        W2_tb <= '1';
        wait for 20 ns;
        W2_tb <= '0';  -- Latch it
        wait for 10 ns;

        -- Verify both held independently
        D_tb <= "000000";
        wait for 20 ns;
        assert O_tb(3 downto 0) = "1010" report "FAIL: Expected O(3:0)=1010 (held), got " & integer'image(to_integer(unsigned(O_tb(3 downto 0)))) severity error;
        assert O_tb(5 downto 4) = "11" report "FAIL: Expected O(5:4)=11 (held), got " & integer'image(to_integer(unsigned(O_tb(5 downto 4)))) severity error;

        -- End simulation
        report "=== IC 6-bit Latch Test Complete ===";
        sim_done <= true;
        wait;
    end process;
end sim;
