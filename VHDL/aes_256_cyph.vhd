library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.AESpkg.all;

entity aes_256_cyph is
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
end entity aes_256_cyph;

architecture rtl of aes_256_cyph is

  type byte_vec     is array (0 to 15) of std_logic_vector(7 downto 0);
  type byte_vec_arr is array (1 to 14) of byte_vec;
  type state_array  is array (0 to 14) of state_type;

  signal round_keys      : std_logic_vector(1919 downto 0);
  signal round_key_valid : std_logic;

  signal st     : state_array;       -- st(r) = state after round r (registered)
  signal sb_in  : byte_vec_arr;      -- ROM addresses for round r
  signal sb_out : byte_vec_arr;      -- ROM outputs for round r (1 clock later)
  signal vld    : std_logic_vector(0 to 28) := (others => '0');

  pure function rk (keys : std_logic_vector(1919 downto 0); r : integer)
    return std_logic_vector is
  begin
    return keys(1919 - 128*r downto 1792 - 128*r);
  end function;

  pure function state_to_bytes (s : state_type) 
    return byte_vec is
    variable b : byte_vec;
  begin
    for i in 0 to 15 loop
      b(i) := s(i mod 4, i / 4);
    end loop;
    return b;
  end function;

  pure function bytes_to_state (b : byte_vec) 
    return state_type is
    variable s : state_type;
  begin
    for i in 0 to 15 loop
      s(i mod 4, i / 4) := b(i);
    end loop;
    return s;
  end function;

begin

  u_key_exp : entity work.key_expansion
    port map (
      clk             => clk,
      key             => key_i,
      key_valid       => key_valid,
      round_keys      => round_keys,
      round_key_valid => round_key_valid
    );

  -- S-boxes: 14 rounds x 8 dual-port ROMs (2 bytes each)
  gen_round : for r in 1 to 14 generate

    sb_in(r) <= state_to_bytes(st(r-1));     -- feeds the ROM addresses

    gen_sb : for k in 0 to 7 generate
      u_sb : entity work.aes_sbox_dp
        port map (
          clk    => clk,
          addr_a => sb_in(r)(2*k),
          dout_a => sb_out(r)(2*k),
          addr_b => sb_in(r)(2*k+1),
          dout_b => sb_out(r)(2*k+1)
        );
    end generate gen_sb;

  end generate gen_round;

  process (clk)
  begin
    if rising_edge(clk) then

      -- initial AddRoundKey
      st(0) <= add_round_key(vector_to_state(data_i), rk(round_keys, 0));

      -- rounds 1..13: sbox (already done by the ROM) -> shift -> mix -> key
      for r in 1 to 13 loop
        st(r) <= add_round_key( mix_columns(shift_rows(bytes_to_state(sb_out(r)))), rk(round_keys, r));
      end loop;

      -- round 14: no MixColumns
      st(14) <= add_round_key(
                  shift_rows(bytes_to_state(sb_out(14))),
                  rk(round_keys, 14));

      -- valid travels with the data
      if rst = '1' then
        vld <= (others => '0');
      else
        vld <= valid_i & vld(0 to 27);
      end if;

    end if;
  end process;

  cyph_data_o  <= state_to_vector(st(14));
  cyph_valid_o <= vld(28) and round_key_valid;
  key_ready_o  <= round_key_valid;

end architecture rtl;