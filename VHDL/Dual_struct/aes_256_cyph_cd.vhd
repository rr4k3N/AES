library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.AESpkg.all;

entity aes_256_cyph_hp is
port (
clk          : in  std_logic;
rst          : in  std_logic;
data_i       : in  std_logic_vector(127 downto 0);
valid_i      : in  std_logic;
key_i        : in  std_logic_vector(255 downto 0);
key_valid    : in  std_logic;
key_ready_o  : out std_logic;
cyph_valid_o : out std_logic;
cyph_data_o  : out std_logic_vector(127 downto 0)
  );
end entity aes_256_cyph_hp;

architecture rtl of aes_256_cyph_hp is

type state_array is array (0 to 27) of state_type;

signal busy            : std_logic;
signal roundkey        : std_logic_vector(127 downto 0);
signal round_idx       : std_logic_vector(3 downto 0);
signal round_key_valid : std_logic;
-- same layout as before: round r at bits (1919-128r downto 1792-128r), round 0 on top (what rk() expects)
signal round_keys      : std_logic_vector(1919 downto 0) := (others => '0');
signal key_ready       : std_logic := '0';
signal vld             : std_logic_vector(0 to 27) := (others => '0');
signal st              : state_array;

begin

u_key_exp : entity work.key_expansion_cd
port map (
clk_i             => clk,
key_i             => key_i,
key_valid_i       => key_valid,
round_key_o       => roundkey,
round_key_valid_o => round_key_valid,
round_idx_o       => round_idx,
busy_o            => busy
    );

-- store each round key in its own fixed slice (static slices, decoded by round_idx)
process (clk)
begin
if rising_edge(clk) then

if key_valid = '1' and busy = '0' then
key_ready <= '0';                                      -- new key being expanded
end if;

if round_key_valid = '1' then
for r in 0 to 14 loop
if to_integer(unsigned(round_idx)) = r then
round_keys(1919 - 128*r downto 1792 - 128*r) <= roundkey;
end if;
end loop;
if to_integer(unsigned(round_idx)) = 14 then
key_ready <= '1';                                      -- last round key is stored with this edge
end if;
end if;

end if;
end process;

-- datapath: free running (no clock enable), blocks must not be in flight during a key load
process (clk)
begin
if rising_edge(clk) then

st(0) <= add_round_key(vector_to_state(data_i), rk(round_keys, 0));

for r in 1 to 13 loop
st(2*r-1) <= sub_state(shift_rows(st(2*r-2)));                          -- ShiftRows + SubBytes
st(2*r)   <= add_round_key(mix_columns(st(2*r-1)), rk(round_keys, r));   -- MixColumns + AddRoundKey
end loop;

st(27) <= add_round_key(shift_rows(sub_state(st(26))), rk(round_keys, 14));

if rst = '1' then
vld <= (others => '0');
else
vld <= valid_i & vld(0 to 26);
end if;

end if;
end process;

cyph_data_o  <= state_to_vector(st(27));
cyph_valid_o <= vld(27) and key_ready;
key_ready_o  <= key_ready;

end architecture rtl;