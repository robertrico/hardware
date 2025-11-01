library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ic3205_tb is
end ic3205_tb;

architecture sim of ic3205_tb is
    -- Component declaration
    component ic3205 is
        port (
            A : in std_logic_vector(2 downto 0);
            E1 : in std_logic;
            E2 : in std_logic;
            E3 : in std_logic;
            O : out std_logic_vector(7 downto 0)
        );
    end component;

    signal sim_done : boolean := false;

    -- Test signals
    signal A_tb : std_logic_vector(2 downto 0) := "000";
    signal E1_tb : std_logic := '0';
    signal E2_tb : std_logic := '0';
    signal E3_tb : std_logic := '0';
    signal O_tb : std_logic_vector(7 downto 0);

begin
    -- Device Under Test
    dut : ic3205
        port map (
            A => A_tb,
            E1 => E1_tb,
            E2 => E2_tb,
            E3 => E3_tb,
            O => O_tb
        );

    -- Main stimulus process
    test_process: process
    begin
        wait for 20 ns;

        -- Test 1-8: All address combinations with proper enable (E3=H, E1=E2=L)
        report "=== Testing all 8 address decodings with E3=H, E1=E2=L ===";
        E1_tb <= '0';
        E2_tb <= '0';
        E3_tb <= '1';

        -- Test 1: Address 000 -> Output 0 should be L, rest H
        report "Test 1: A=000, E=(L,L,H) -> expect O=01111111 (O0=L, rest H)";
        A_tb <= "000";
        wait for 20 ns;
        assert O_tb = "11111110" report "FAIL: Expected 11111110, got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- Test 2: Address 001 -> Output 1 should be L, rest H
        report "Test 2: A=001, E=(L,L,H) -> expect O=11111101 (O1=L, rest H)";
        A_tb <= "001";
        wait for 20 ns;
        assert O_tb = "11111101" report "FAIL: Expected 11111101, got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- Test 3: Address 010 -> Output 2 should be L, rest H
        report "Test 3: A=010, E=(L,L,H) -> expect O=11111011 (O2=L, rest H)";
        A_tb <= "010";
        wait for 20 ns;
        assert O_tb = "11111011" report "FAIL: Expected 11111011, got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- Test 4: Address 011 -> Output 3 should be L, rest H
        report "Test 4: A=011, E=(L,L,H) -> expect O=11110111 (O3=L, rest H)";
        A_tb <= "011";
        wait for 20 ns;
        assert O_tb = "11110111" report "FAIL: Expected 11110111, got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- Test 5: Address 100 -> Output 4 should be L, rest H
        report "Test 5: A=100, E=(L,L,H) -> expect O=11101111 (O4=L, rest H)";
        A_tb <= "100";
        wait for 20 ns;
        assert O_tb = "11101111" report "FAIL: Expected 11101111, got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- Test 6: Address 101 -> Output 5 should be L, rest H
        report "Test 6: A=101, E=(L,L,H) -> expect O=11011111 (O5=L, rest H)";
        A_tb <= "101";
        wait for 20 ns;
        assert O_tb = "11011111" report "FAIL: Expected 11011111, got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- Test 7: Address 110 -> Output 6 should be L, rest H
        report "Test 7: A=110, E=(L,L,H) -> expect O=10111111 (O6=L, rest H)";
        A_tb <= "110";
        wait for 20 ns;
        assert O_tb = "10111111" report "FAIL: Expected 10111111, got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- Test 8: Address 111 -> Output 7 should be L, rest H
        report "Test 8: A=111, E=(L,L,H) -> expect O=01111111 (O7=L, rest H)";
        A_tb <= "111";
        wait for 20 ns;
        assert O_tb = "01111111" report "FAIL: Expected 01111111, got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- Test 9-10: Invalid enable combinations (all outputs should be H)
        report "=== Testing disabled states ===";

        -- Test 9: E1=E2=E3=L -> All outputs H
        report "Test 9: A=000, E=(L,L,L) -> expect O=11111111 (all disabled)";
        A_tb <= "000";
        E1_tb <= '0';
        E2_tb <= '0';
        E3_tb <= '0';
        wait for 20 ns;
        assert O_tb = "11111111" report "FAIL: Expected 11111111 (disabled), got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- Test 10: E1=H, E2=L, E3=H -> All outputs H (E1 wrong)
        report "Test 10: A=010, E=(H,L,H) -> expect O=11111111 (E1 wrong)";
        A_tb <= "010";
        E1_tb <= '1';
        E2_tb <= '0';
        E3_tb <= '1';
        wait for 20 ns;
        assert O_tb = "11111111" report "FAIL: Expected 11111111 (E1 wrong), got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- Test 11: E1=L, E2=H, E3=H -> All outputs H (E2 wrong)
        report "Test 11: A=101, E=(L,H,H) -> expect O=11111111 (E2 wrong)";
        A_tb <= "101";
        E1_tb <= '0';
        E2_tb <= '1';
        E3_tb <= '1';
        wait for 20 ns;
        assert O_tb = "11111111" report "FAIL: Expected 11111111 (E2 wrong), got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- Test 12: E1=L, E2=L, E3=L -> All outputs H (E3 wrong)
        report "Test 12: A=111, E=(L,L,L) -> expect O=11111111 (E3 wrong)";
        A_tb <= "111";
        E1_tb <= '0';
        E2_tb <= '0';
        E3_tb <= '0';
        wait for 20 ns;
        assert O_tb = "11111111" report "FAIL: Expected 11111111 (E3 wrong), got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- Test 13: E1=E2=E3=H -> All outputs H (wrong combination)
        report "Test 13: A=011, E=(H,H,H) -> expect O=11111111 (all enables wrong)";
        A_tb <= "011";
        E1_tb <= '1';
        E2_tb <= '1';
        E3_tb <= '1';
        wait for 20 ns;
        assert O_tb = "11111111" report "FAIL: Expected 11111111 (all enables wrong), got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- Test 14: Verify address doesn't matter when disabled
        report "Test 14: A=XXX, E=(H,L,L) -> expect O=11111111 (disabled)";
        A_tb <= "101";
        E1_tb <= '1';
        E2_tb <= '0';
        E3_tb <= '0';
        wait for 20 ns;
        assert O_tb = "11111111" report "FAIL: Expected 11111111 (disabled), got " & integer'image(to_integer(unsigned(O_tb))) severity error;

        -- End simulation
        report "=== IC3205 Test Complete ===";
        sim_done <= true;
        wait;
    end process;
end sim;
