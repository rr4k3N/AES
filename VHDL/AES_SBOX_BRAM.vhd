library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.AESpkg.all;   -- needs SBOX_TABLE visible, see note below

entity aes_sbox_dp is
  port (
    clk    : in  std_logic;
    addr_a : in  std_logic_vector(7 downto 0);
    dout_a : out std_logic_vector(7 downto 0);
    addr_b : in  std_logic_vector(7 downto 0);
    dout_b : out std_logic_vector(7 downto 0)
  );
end entity aes_sbox_dp;

architecture rtl of aes_sbox_dp is

  constant ROM : byte_array := SBOX_TABLE;     -- local copy, declared here

  attribute rom_style : string;
  attribute rom_style of ROM : constant is "block";

begin

  process (clk)
  begin
    if rising_edge(clk) then
      dout_a <= ROM(to_integer(unsigned(addr_a)));
      dout_b <= ROM(to_integer(unsigned(addr_b)));
    end if;
  end process;

end architecture rtl;