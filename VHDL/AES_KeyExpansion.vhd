library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;              
use work.AESpkg.all;        

entity key_expansion is
    port (
        clk : in  std_logic;
        key : in  std_logic_vector(255 downto 0);
        rk  : out std_logic_vector(127 downto 0)
    );
end entity key_expansion;

architecture rtl of key_expansion is
    
begin




end architecture rtl;