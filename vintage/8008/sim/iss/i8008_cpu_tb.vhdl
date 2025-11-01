library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i8008_cpu_tb is
end i8008_cpu_tb;

architecture sim of i8008_cpu_tb is
    component i8008_cpu is
        port(
            clk : in std_logic;
            reset_n : in std_logic;
            mem_address : out std_logic_vector(13 downto 0);
            mem_data_in : out std_logic_vector(7 downto 0);
            mem_data_out : in std_logic_vector(7 downto 0);
            mem_read : out std_logic;
            mem_write : out std_logic;
            halted : out std_logic
        );
    end component;

    constant CLK_PERIOD : time := 10 ns;

    signal clk_tb : std_logic := '0';
    signal reset_n_tb : std_logic := '0';
    signal mem_address_tb : std_logic_vector(13 downto 0);
    signal mem_data_in_tb : std_logic_vector(7 downto 0);
    signal mem_data_out_tb : std_logic_vector(7 downto 0) := (others => '0');
    signal mem_read_tb : std_logic;
    signal mem_write_tb : std_logic;
    signal halted_tb : std_logic;
    signal sim_done : boolean := false;

    -- Simple test program memory
    type memory_array is array(0 to 255) of std_logic_vector(7 downto 0);
    signal test_memory : memory_array := (
        -- Simple test program: NOP, then HLT
        0 => x"00",  -- NOP (or could be interpreted as part of other instruction)
        1 => x"FF",  -- HLT (11_111_111)
        2 => x"00",  -- Padding
        others => x"00"
    );

begin
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

    -- DUT instantiation
    dut : i8008_cpu
        port map(
            clk => clk_tb,
            reset_n => reset_n_tb,
            mem_address => mem_address_tb,
            mem_data_in => mem_data_in_tb,
            mem_data_out => mem_data_out_tb,
            mem_read => mem_read_tb,
            mem_write => mem_write_tb,
            halted => halted_tb
        );

    -- Simple memory model
    mem_process: process(clk_tb)
    begin
        if rising_edge(clk_tb) then
            if mem_read_tb = '1' then
                mem_data_out_tb <= test_memory(to_integer(unsigned(mem_address_tb)));
            end if;

            if mem_write_tb = '1' then
                test_memory(to_integer(unsigned(mem_address_tb))) <= mem_data_in_tb;
            end if;
        end if;
    end process;

    -- Test stimulus
    test_process: process
    begin
        -- Hold reset
        reset_n_tb <= '0';
        wait for 50 ns;

        -- Release reset
        reset_n_tb <= '1';
        report "=== Starting i8008 CPU Test ===";
        wait for 20 ns;

        -- Wait for CPU to execute and halt
        wait until halted_tb = '1' for 1 us;

        if halted_tb = '1' then
            report "=== CPU Halted Successfully ===";
        else
            report "=== ERROR: CPU did not halt ===" severity error;
        end if;

        wait for 100 ns;
        report "=== i8008 CPU Test Complete ===";
        sim_done <= true;
        wait;
    end process;

end sim;
