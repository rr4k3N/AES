library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.AESpkg.all;

entity key_expansion_it is
  port (
    clk             : in  std_logic;
    key             : in  std_logic_vector(255 downto 0);
    key_valid       : in  std_logic;
    round_keys      : out std_logic_vector(1919 downto 0);  -- 15 x 128, round 0 in the MSBs
    round_key_valid : out std_logic
  );
end entity key_expansion_it;

architecture iter of key_expansion_it is
  type win_t is array (0 to 7) of std_logic_vector(31 downto 0);

  signal rk_regs : word_array := (others => (others => '0'));
  signal win     : win_t;                    -- win(0)=w[i-8] ... win(7)=w[i-1]
  signal idx     : unsigned(5 downto 0) := (others => '0');
  signal busy    : std_logic := '0';
  signal done    : std_logic := '0';
begin

  process (clk)
    variable new_w : std_logic_vector(31 downto 0);
  begin
    if rising_edge(clk) then
      if key_valid = '1' then
        for j in 0 to 7 loop
          rk_regs(j) <= key(255 - 32*j downto 224 - 32*j);
          win(j)     <= key(255 - 32*j downto 224 - 32*j);
        end loop;
        idx  <= to_unsigned(8, 6);
        busy <= '1';
        done <= '0';

      elsif busy = '1' then
        new_w := round_exp(win(7), win(0), to_integer(idx));
        rk_regs(to_integer(idx)) <= new_w;
        win <= win(1 to 7) & new_w;          -- shift the window

        if idx = 59 then
          busy <= '0';
          done <= '1';
        else
          idx <= idx + 1;
        end if;
      end if;
    end if;
  end process;

  round_key_valid <= done;

  gen_out : for r in 0 to 14 generate
    round_keys(1919 - 128*r downto 1792 - 128*r) <=
      rk_regs(4*r) & rk_regs(4*r+1) & rk_regs(4*r+2) & rk_regs(4*r+3);
  end generate gen_out;

end architecture iter;