library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.AESpkg.all;

entity key_expansion is
  port (
    clk             : in  std_logic;
    key             : in  std_logic_vector(255 downto 0);
    key_valid       : in  std_logic;
    round_keys      : out std_logic_vector(1919 downto 0);  -- 15 x 128, round 0 in the MSBs
    round_key_valid : out std_logic
  );
end entity key_expansion;

architecture rtl of key_expansion is
  signal rk_regs    : word_array := (others => (others => '0'));
  signal valid_wait : unsigned(5 downto 0) := (others => '0');
  signal busy       : std_logic := '0';
begin

  process (clk)
  begin
    if rising_edge(clk) then

      -- stages 0..7 hold the raw key
      if key_valid = '1' then
        for i in 0 to 7 loop
          rk_regs(i) <= key(255 - 32*i downto 224 - 32*i);
        end loop;
        valid_wait <= (others => '0');
        busy       <= '1';
      elsif valid_wait < 52 then
        valid_wait <= valid_wait + 1;
      end if;

      -- stages 8..59: w[i] = f(w[i-1], w[i-8])
      for i in 8 to 59 loop
        rk_regs(i) <= round_exp(rk_regs(i-1), rk_regs(i-8), i);
      end loop;

    end if;
  end process;

  round_key_valid <= '1' when (busy = '1' and valid_wait = 52) else '0';

  gen_out : for r in 0 to 14 generate
    round_keys(1919 - 128*r downto 1792 - 128*r) <=
      rk_regs(4*r) & rk_regs(4*r+1) & rk_regs(4*r+2) & rk_regs(4*r+3);
  end generate gen_out;

end architecture rtl;
