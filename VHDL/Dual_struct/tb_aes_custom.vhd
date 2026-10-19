-----------------------------------------
--  Testbench for the pipelined AES-256
--  (entity aes_256_cyph)
-----------------------------------------
-- Vectors 1, 2 : NIST SP 800-38A, F.1.5 (ECB-AES256, blocks 1 and 2)
-- Vector 3     : FIPS-197, appendix C.3

library ieee;
use ieee.std_logic_1164.all;

entity tb_aes is
end entity tb_aes;

architecture testbench of tb_aes is

  constant per        : time    := 10 ns;   -- 100 MHz
  constant KEY_SETTLE : integer := 60;      -- clocks for the key expansion chain (needs 52)

  signal clk          : std_logic := '0';
  signal rst          : std_logic := '1';
  signal data_i       : std_logic_vector(127 downto 0) := (others => '0');
  signal valid_i      : std_logic := '0';
  signal key_i        : std_logic_vector(255 downto 0) := (others => '0');
  signal key_valid    : std_logic := '0';
  signal cyph_valid_o : std_logic;
  signal cyph_data_o  : std_logic_vector(127 downto 0);

  -- keys
  constant k1 : std_logic_vector(255 downto 0) :=
    X"603DEB1015CA71BE2B73AEF0857D77811F352C073B6108D72D9810A30914DFF4";
  constant k3 : std_logic_vector(255 downto 0) :=
    X"000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F";

  -- plaintexts
  constant in1 : std_logic_vector(127 downto 0) := X"6BC1BEE22E409F96E93D7E117393172A";
  constant in2 : std_logic_vector(127 downto 0) := X"AE2D8A571E03AC9C9EB76FAC45AF8E51";
  constant in3 : std_logic_vector(127 downto 0) := X"00112233445566778899AABBCCDDEEFF";

  -- expected ciphertexts
  constant out1 : std_logic_vector(127 downto 0) := X"F3EED1BDB5D2A03C064B5A7E3DB181F8";
  constant out2 : std_logic_vector(127 downto 0) := X"591CCB10D410ED26DC5BA74A31362870";
  constant out3 : std_logic_vector(127 downto 0) := X"8EA2B7CA516745BFEAFC49904B496089";

  type vec_arr is array (0 to 2) of std_logic_vector(127 downto 0);
  constant expected : vec_arr := (out1, out2, out3);

  signal n_checked : integer := 0;
  signal n_errors  : integer := 0;
  signal finished  : boolean := false;
  signal done      : boolean := false;

begin

  -- clock, stops when done so that "run -all" terminates
  clk_gen : process
  begin
    while not done loop
      clk <= '0';
      wait for per/2;
      clk <= '1';
      wait for per/2;
    end loop;
    wait;
  end process clk_gen;

  -- watchdog
  watchdog : process
  begin
    wait until finished for 20 us;
    if not finished then
      report "TIMEOUT: expected outputs never arrived" severity error;
    end if;
    done <= true;
    wait;
  end process watchdog;

  -- stimulus
  stim : process

    procedure tick (n : integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure tick;

  begin
    -- reset
    rst <= '1';
    tick(3);
    wait until falling_edge(clk);
    rst <= '0';
    tick(2);

    ----------------------------------------------------------------
    -- key 1, then two back-to-back blocks (tests streaming)
    ----------------------------------------------------------------
    key_i     <= k1;
    key_valid <= '1';
    tick(1);
    key_valid <= '0';
    key_i     <= (others => '0');   -- key must not be needed after the pulse
    tick(KEY_SETTLE);

    data_i  <= in1;
    valid_i <= '1';
    tick(1);
    data_i  <= in2;                 -- next block on the very next clock
    tick(1);
    valid_i <= '0';
    data_i  <= (others => '0');

    wait until n_checked = 2;       -- pipeline is empty again
    tick(5);

    ----------------------------------------------------------------
    -- key 3 (FIPS-197), one block
    ----------------------------------------------------------------
    key_i     <= k3;
    key_valid <= '1';
    tick(1);
    key_valid <= '0';
    key_i     <= (others => '0');
    tick(KEY_SETTLE);

    data_i  <= in3;
    valid_i <= '1';
    tick(1);
    valid_i <= '0';
    data_i  <= (others => '0');

    wait until n_checked = 3;
    tick(5);

    if n_errors = 0 then
      report "All tests succeeded";
    else
      report "At least one test failed" severity error;
    end if;

    finished <= true;
    wait;
  end process stim;

  -- checker: samples every valid output on the falling edge
  check : process (clk)
    variable idx  : integer := 0;
    variable errs : integer := 0;
  begin
    if falling_edge(clk) then
      if cyph_valid_o = '1' and idx <= 2 then
        if cyph_data_o /= expected(idx) then
          report "vector " & integer'image(idx + 1) & " : MISMATCH" severity error;
          errs := errs + 1;
        else
          report "vector " & integer'image(idx + 1) & " : ok";
        end if;
        idx := idx + 1;
        n_checked <= idx;
        n_errors  <= errs;
      end if;
    end if;
  end process check;

  -- device under test
  dut : entity work.aes_256_cyph_hp
    port map (
      clk          => clk,
      rst          => rst,
      data_i       => data_i,
      valid_i      => valid_i,
      key_i        => key_i,
      key_valid    => key_valid,
      cyph_valid_o => cyph_valid_o,
      cyph_data_o  => cyph_data_o
    );

end architecture testbench;