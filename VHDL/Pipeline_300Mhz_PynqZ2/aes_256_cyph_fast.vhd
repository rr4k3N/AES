library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.AESpkg.all;

entity aes_256_cyph_fast is
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
end entity aes_256_cyph_fast;

architecture rtl of aes_256_cyph_fast is

type state_array is array (0 to 27) of state_type;

signal round_keys      : std_logic_vector(1919 downto 0);
signal round_key_valid : std_logic;
signal vld : std_logic_vector(0 to 27) := (others => '0');
signal st  : state_array;


begin

u_key_exp : entity work.key_expansion_revb
port map (
clk             => clk,
key             => key_i,
key_valid       => key_valid,
round_keys      => round_keys,
round_key_valid => round_key_valid
    );

process (clk)
begin
if rising_edge(clk) then

-- initial AddRoundKey
st(0) <= add_round_key(vector_to_state(data_i), rk(round_keys, 0));

-- rounds 1..13, two stages each
for r in 1 to 13 loop
st(2*r-1) <= sub_state(shift_rows(st(2*r-2)));                        -- ShiftRows + SubBytes
st(2*r)   <= add_round_key(mix_columns(st(2*r-1)), rk(round_keys, r)); -- MixColumns + AddRoundKey
end loop;

-- round 14: no MixColumns, one stage
st(27) <= add_round_key(shift_rows(sub_state(st(26))), rk(round_keys, 14));

if rst = '1' then
vld <= (others => '0');
else
vld <= valid_i & vld(0 to 26);
end if;


end if;
end process;

cyph_data_o  <= state_to_vector(st(27));
cyph_valid_o <= vld(27) and round_key_valid;
key_ready_o  <= round_key_valid;

end architecture rtl;