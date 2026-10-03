library ieee;

entity AESTOP is
    generic ();
    port(
    data_i : in std_logic_vector(127 downto 0),
    key_i : in std_logic_vector(255 downto 0),
    valid_i : in std_logic,
    clk : in std_logic,
    rst : in std_logic
    err : out std_logic,
    cyph_data_o : out std_logic_vector(255 downto 0);
    );
end entity AESTOP;

architecture rtl of AESTOP is
    



    begin



end architecture rtl;