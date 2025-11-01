library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ic8263_tb is
end ic8263_tb;

architecture sim of ic8263_tb is
    -- Component declaration
    component ic8263 is
        port (
            A : in std_logic_vector(3 downto 0);
            B : in std_logic_vector(3 downto 0);
            C : in std_logic_vector(3 downto 0);
            SEL : in std_logic_vector(1 downto 0);
            OE : in std_logic_vector(2 downto 0);
            D : in std_logic;
            Y : out std_logic_vector(3 downto 0)
        );
    end component;

    signal sim_done : boolean := false;

    -- Test signals
    signal A_tb : std_logic_vector(3 downto 0) := "0000";
    signal B_tb : std_logic_vector(3 downto 0) := "0000";
    signal C_tb : std_logic_vector(3 downto 0) := "0000";
    signal SEL_tb : std_logic_vector(1 downto 0) := "00";
    signal OE_tb : std_logic_vector(2 downto 0) := "111";
    signal D_tb : std_logic := '0';
    signal Y_tb : std_logic_vector(3 downto 0);

begin
    -- Device Under Test
    dut : ic8263
        port map (
            A => A_tb,
            B => B_tb,
            C => C_tb,
            SEL => SEL_tb,
            OE => OE_tb,
            D => D_tb,
            Y => Y_tb
        );

    -- Main stimulus process
    test_process: process
    begin
        -- Setup test values for inputs
        A_tb <= "1010";  -- 0xA
        B_tb <= "1100";  -- 0xC
        C_tb <= "0011";  -- 0x3

        wait for 20 ns;

        -- Test 1: Select A, no complement, OE enabled
        report "Test 1: SEL=11 (A), D=L, OE=H -> expect A=1010";
        SEL_tb <= "11";
        D_tb <= '0';
        OE_tb <= "111";
        wait for 20 ns;

        -- Test 2: Select B, no complement, OE enabled
        report "Test 2: SEL=01 (B), D=L, OE=H -> expect B=1100";
        SEL_tb <= "01";
        D_tb <= '0';
        OE_tb <= "111";
        wait for 20 ns;

        -- Test 3: Select C, no complement, OE enabled
        report "Test 3: SEL=10 (C), D=L, OE=H -> expect C=0011";
        SEL_tb <= "10";
        D_tb <= '0';
        OE_tb <= "111";
        wait for 20 ns;

        -- Test 4: Select nothing (00), no complement, OE enabled
        report "Test 4: SEL=00, D=L, OE=H -> expect 0000";
        SEL_tb <= "00";
        D_tb <= '0';
        OE_tb <= "111";
        wait for 20 ns;

        -- Test 5: Select A, WITH complement, OE enabled
        report "Test 5: SEL=11 (A), D=H, OE=H -> expect NOT A=0101";
        SEL_tb <= "11";
        D_tb <= '1';
        OE_tb <= "111";
        wait for 20 ns;

        -- Test 6: Select B, WITH complement, OE enabled
        report "Test 6: SEL=01 (B), D=H, OE=H -> expect NOT B=0011";
        SEL_tb <= "01";
        D_tb <= '1';
        OE_tb <= "111";
        wait for 20 ns;

        -- Test 7: Select C, WITH complement, OE enabled
        report "Test 7: SEL=10 (C), D=H, OE=H -> expect NOT C=1100";
        SEL_tb <= "10";
        D_tb <= '1';
        OE_tb <= "111";
        wait for 20 ns;

        -- Test 8: Select nothing (00), WITH complement, OE enabled
        report "Test 8: SEL=00, D=H, OE=H -> expect 1111 (H)";
        SEL_tb <= "00";
        D_tb <= '1';
        OE_tb <= "111";
        wait for 20 ns;

        -- Test 9: OE disabled (all bits L) - should output H (1111) regardless
        report "Test 9: SEL=11 (A), D=L, OE=000 -> expect 1111 (H) - OE disabled";
        SEL_tb <= "11";
        D_tb <= '0';
        OE_tb <= "000";
        wait for 20 ns;
        assert Y_tb = "1111" report "FAIL: OE disabled should output 1111, got " & integer'image(to_integer(unsigned(Y_tb))) severity error;

        -- Test 10: OE partially disabled (one bit L) - should output H (1111)
        report "Test 10: SEL=01 (B), D=L, OE=110 -> expect 1111 (H) - OE partially disabled";
        SEL_tb <= "01";
        D_tb <= '0';
        OE_tb <= "110";
        wait for 20 ns;
        assert Y_tb = "1111" report "FAIL: OE partially disabled should output 1111, got " & integer'image(to_integer(unsigned(Y_tb))) severity error;

        -- Test 11: SEL=00 with D=H should output 1111 (H), not 0000
        report "Test 11: SEL=00, D=H, OE=111 -> expect 1111 (H)";
        SEL_tb <= "00";
        D_tb <= '1';
        OE_tb <= "111";
        wait for 20 ns;
        assert Y_tb = "1111" report "FAIL: SEL=00 with D=1 should output 1111, got " & integer'image(to_integer(unsigned(Y_tb))) severity error;

        -- End simulation
        report "=== IC8263 Test Complete ===";
        sim_done <= true;
        wait;
    end process;
end sim;