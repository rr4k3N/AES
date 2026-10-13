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
    cyph_valid_o : out std_logic;
    cyph_data_o  : out std_logic_vector(127 downto 0)
  );
end entity aes_256_cyph;

architecture rtl of aes_256_cyph is

  signal round_keys      : std_logic_vector(1919 downto 0);
  signal round_key_valid : std_logic;
  signal aes_state_pipe  : state_type;   -- from AESpkg

begin

  u_key_exp : entity work.key_expansion
    port map (
      clk             => clk,
      key             => key_i,
      key_valid       => key_valid,
      round_keys      => round_keys,
      round_key_valid => round_key_valid
    );

  aes_state_pipe <= vector_to_state(data_i);
  aes_state_pipe <= add_round_key(aes_state_pipe,round_keys(1919 downto 1792));

  process (clk) is
  begin
    if rising_edge(clk) then

        for i in 2 to 12 loop
            aes_state_pipe <= add_round_key(aes_state_pipe,round_keys(1919 - 128*i downto 1792 - 128*i));
            aes_state_pipe <= 
        end loop;



    end if;


end architecture rtl;