library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.AESpkg.all;

entity key_expansion_revb is
  port (
    clk             : in  std_logic;
    key             : in  std_logic_vector(255 downto 0);
    key_valid       : in  std_logic;
    round_keys      : out std_logic_vector(1919 downto 0);  -- 15 x 128, round 0 in the MSBs
    round_key_valid : out std_logic
  );
end entity key_expansion_revb;

architecture rtl of key_expansion_revb is
  signal rk_regs    : key_arrays := (others => (others => '0'));
  signal valid_wait : unsigned(5 downto 0) := (others => '0');
  signal busy       : std_logic := '0';
  
  


begin

  process (clk)
    variable w0,w1,w2,w3 : std_logic_vector(31 downto 0);
  begin
    if rising_edge(clk) then
        

      if key_valid = '1' then
        rk_regs(1) <= key(127 downto 0);
        rk_regs(0) <= key(255 downto 128);
        valid_wait <= (others => '0');
        busy       <= '1';
      elsif valid_wait < 13 then
        valid_wait <= valid_wait + 1;
      end if;

      -- stages 8..59: w[i] = f(w[i-1], w[i-8])
        for i in 2 to 14 loop
            if (i mod 2) = 0 then
               w0 := rk_regs(i-2)(127 downto 96) xor sub_word(rot_word(rk_regs(i-1)(31 downto 0))) xor (RCON(i/2) & x"000000");
            else
                w0 := rk_regs(i-2)(127 downto 96) xor sub_word(rk_regs(i-1)(31 downto 0));
            end if;

            w1 := w0 xor rk_regs(i-2)(95 downto 64);
            w2 := w1 xor rk_regs(i-2)(63 downto 32);
            w3 := w2 xor rk_regs(i-2)(31 downto 0);


            rk_regs(i) <= w0 & w1 & w2 & w3;

        end loop;

    end if;
  end process;

  round_key_valid <= '1' when (busy = '1' and valid_wait = 13) else '0';

  gen_out : for r in 0 to 14 generate
    round_keys(1919 - 128*r downto 1792 - 128*r) <= rk_regs(r);
  end generate gen_out;

end architecture rtl;
