library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;              
use work.AESpkg.all;  


entity AESTOP is
    generic ();
    port(
    clk : in std_logic,
    rst : in std_logic,
    data_i : in std_logic_vector(127 downto 0),
    valid_i : in std_logic,
    key_i : in std_logic_vector(255 downto 0),
    key_valid : in std_logic,
    cyph_valid_o : out std_logic,
    cyph_data_o : out std_logic_vector(255 downto 0);
    );
end entity AESTOP;

architecture rtl of AESTOP is
    



    begin



end architecture rtl;