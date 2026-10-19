library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.AESpkg.all;

-- Iterative AES-256 key expansion, one word per clock.
-- rk_reg: OLDEST word on top (255:224 = w[i-8]), NEWEST at the bottom (31:0 = w[i-1]).
-- Round keys come out in order 0..14, round_idx_o tells which one:
--   round key 0 : on the load clock            (w0..w3)
--   round key k : at count = 4k+4 (k = 1..14)  (w[4k]..w[4k+3])
entity key_expansion_cd is
port(
clk_i             : in  std_logic;
key_i             : in  std_logic_vector(255 downto 0);
key_valid_i       : in  std_logic;
round_key_o       : out std_logic_vector(127 downto 0);
round_key_valid_o : out std_logic;
round_idx_o       : out std_logic_vector(3 downto 0);
busy_o            : out std_logic
);
end entity key_expansion_cd;

architecture RTL of key_expansion_hp is

signal rk_reg : std_logic_vector(255 downto 0) := (others => '0');
signal busy   : std_logic := '0';
signal count  : integer range 8 to 60 := 8;

begin

process (clk_i)
begin
if rising_edge(clk_i) then

round_key_valid_o <= '0';                               -- default: no output this clock

if key_valid_i = '1' and busy = '0' then
rk_reg            <= key_i;
busy              <= '1';
count             <= 8;
round_key_o       <= key_i(255 downto 128);              -- round key 0
round_idx_o       <= std_logic_vector(to_unsigned(0, 4));
round_key_valid_o <= '1';
end if;

if busy = '1' then

-- the newest 4 words of the window are a complete round key every 4th clock
if count mod 4 = 0 then
round_key_o       <= rk_reg(127 downto 0);
round_idx_o       <= std_logic_vector(to_unsigned(count/4 - 1, 4));
round_key_valid_o <= '1';
end if;

if count < 60 then
if (count mod 8 = 0) then
rk_reg <= rk_reg(223 downto 0) & (rk_reg(255 downto 224) xor sub_word(rot_word(rk_reg(31 downto 0))) xor (RCON(count/8) & x"000000"));
elsif (count mod 8 = 4) then
rk_reg <= rk_reg(223 downto 0) & (rk_reg(255 downto 224) xor sub_word(rk_reg(31 downto 0)));
else
rk_reg <= rk_reg(223 downto 0) & (rk_reg(255 downto 224) xor rk_reg(31 downto 0));
end if;
count <= count + 1;
else
busy <= '0';
end if;

end if;

end if;
end process;

busy_o <= busy;

end architecture RTL;