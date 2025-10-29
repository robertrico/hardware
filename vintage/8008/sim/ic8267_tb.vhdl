library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ic8267_tb is
end ic8267_tb;

architecture sim of ic8267_tb is
    -- Component declaration
    component ic8267 is
        port (
            A : in std_logic_vector(3 downto 0);
            B : in std_logic_vector(3 downto 0);
            S0 : in std_logic;
            S1 : in std_logic;
            Y : out std_logic_vector(3 downto 0)
        );
    end component;

    signal sim_done : boolean := false;

    -- Test signals
    signal A_tb : std_logic_vector(3 downto 0) := "0000";
    signal B_tb : std_logic_vector(3 downto 0) := "0000";
    signal S0_tb : std_logic := '0';
    signal S1_tb : std_logic := '0';
    signal Y_tb : std_logic_vector(3 downto 0);

begin
    -- Device Under Test
    dut : ic8267
        port map (
            A => A_tb,
            B => B_tb,
            S0 => S0_tb,
            S1 => S1_tb,
            Y => Y_tb
        );

    -- Main stimulus process
    test_process: process
    begin
        -- Setup test values
        A_tb <= "1010";  -- 0xA
        B_tb <= "0011";  -- 0x3

        wait for 20 ns;

        -- Test 1: S0=0, S1=0 -> Select B
        report "Test 1: S0=0, S1=0 -> expect B (0011)";
        S0_tb <= '0';
        S1_tb <= '0';
        wait for 20 ns;
        assert Y_tb = "0011" report "FAIL: Expected B (0011), got " & integer'image(to_integer(unsigned(Y_tb))) severity error;

        -- Test 2: S0=0, S1=1 -> Select B
        report "Test 2: S0=0, S1=1 -> expect B (0011)";
        S0_tb <= '0';
        S1_tb <= '1';
        wait for 20 ns;
        assert Y_tb = "0011" report "FAIL: Expected B (0011), got " & integer'image(to_integer(unsigned(Y_tb))) severity error;

        -- Test 3: S0=1, S1=0 -> Select NOT A
        report "Test 3: S0=1, S1=0 -> expect NOT A (0101)";
        S0_tb <= '1';
        S1_tb <= '0';
        wait for 20 ns;
        assert Y_tb = "0101" report "FAIL: Expected NOT A (0101), got " & integer'image(to_integer(unsigned(Y_tb))) severity error;

        -- Test 4: S0=1, S1=1 -> Output all 1s
        report "Test 4: S0=1, S1=1 -> expect 1111";
        S0_tb <= '1';
        S1_tb <= '1';
        wait for 20 ns;
        assert Y_tb = "1111" report "FAIL: Expected 1111, got " & integer'image(to_integer(unsigned(Y_tb))) severity error;

        -- Test 5: Different values to verify proper routing
        A_tb <= "1111";
        B_tb <= "0000";
        wait for 20 ns;

        -- Test 6: S0=0, S1=0 -> Select B (now 0000)
        report "Test 6: S0=0, S1=0 -> expect B (0000)";
        S0_tb <= '0';
        S1_tb <= '0';
        wait for 20 ns;
        assert Y_tb = "0000" report "FAIL: Expected B (0000), got " & integer'image(to_integer(unsigned(Y_tb))) severity error;

        -- Test 7: S0=1, S1=0 -> Select NOT A (now 0000 since A=1111)
        report "Test 7: S0=1, S1=0 -> expect NOT A (0000)";
        S0_tb <= '1';
        S1_tb <= '0';
        wait for 20 ns;
        assert Y_tb = "0000" report "FAIL: Expected NOT A (0000), got " & integer'image(to_integer(unsigned(Y_tb))) severity error;

        -- End simulation
        report "=== IC8267 Test Complete ===";
        sim_done <= true;
        wait;
    end process;
end sim;
