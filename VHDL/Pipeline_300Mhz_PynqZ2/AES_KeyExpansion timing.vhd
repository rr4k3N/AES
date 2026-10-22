library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.AESpkg.all;

entity key_expansion_timing is
  port (
    clk             : in  std_logic;
    key             : in  std_logic_vector(255 downto 0);
    key_valid       : in  std_logic;
    round_keys      : out std_logic_vector(1919 downto 0);  
    round_key_valid : out std_logic
  );
end entity key_expansion_timing;

architecture rtl of key_expansion_timing is
  signal rk_regs    : word_array := (others => (others => '0'));
  signal inter_regs : word_array := (others => (others => '0'));
  signal valid_wait : unsigned(5 downto 0) := (others => '0');
  signal busy       : std_logic := '0';
begin

  process (clk)
  begin
    if rising_edge(clk) then

      if key_valid = '1' then

        for i in 0 to 7 loop

          rk_regs(i) <= key(255 - 32*i downto 224 - 32*i);

        end loop;

        valid_wait <= (others => '0');
        busy       <= '1';

      elsif valid_wait < 52 then

        valid_wait <= valid_wait + 1;

      end if;





      for i in 8 to 59 loop

        if (i mod 8) = 0 then

          inter_regs(i) <= sub_word(rot_word(rk_regs(i-1))) xor (RCON(i/8) & x"000000");
          rk_regs(i) <= rk_regs(i-8) xor inter_regs(i);

        elsif (i mod 8 = 4) then

          rk_regs(i) <= sub_word(rk_regs(i-1)) xor rk_regs((i-8));

        else

          rk_regs(i) <= rk_regs(i-1) xor rk_regs((i-8));

        end if;

      end loop;



    end if;
  end process;

  round_key_valid <= '1' when (busy = '1' and valid_wait = 52) else '0';

  gen_out : for r in 0 to 14 generate

    round_keys(1919 - 128*r downto 1792 - 128*r) <= rk_regs(4*r) & rk_regs(4*r+1) & rk_regs(4*r+2) & rk_regs(4*r+3);

  end generate gen_out;

end architecture rtl;
