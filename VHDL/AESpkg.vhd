library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package AESpkg is

    type state_type is array (3 downto 0, 3 downto 0) of STD_LOGIC_VECTOR (7 downto 0);
    
    type word_array is array (0 to 59) of std_logic_vector(31 downto 0);   -- header


    pure function vector_to_state (
        x : std_logic_vector( 127 downto 0)
    ) return state_type;

    -- GF(2^8) multiplication by 2
    pure function gf_mult_by2 (
        x : std_logic_vector(7 downto 0)
    ) return std_logic_vector;

    pure function gf_mult_by3 (
        x : std_logic_vector(7 downto 0)
    ) return std_logic_vector;

    -- AES MixColumns for one 32-bit column
    pure function mix_column(
        x : std_logic_vector(31 downto 0)
    ) return std_logic_vector;



end package AESpkg;


package body AESpkg is

    constant RCON : rcon_array := (x"01", x"02", x"04", x"08", x"10", x"20", x"40");

    constant SBOX_TABLE : byte_array := (
       -- x = 0
        0   => x"63",  1   => x"7C",  2   => x"77",  3   => x"7B",
        4   => x"F2",  5   => x"6B",  6   => x"6F",  7   => x"C5",
        8   => x"30",  9   => x"01",  10  => x"67",  11  => x"2B",
        12  => x"FE",  13  => x"D7",  14  => x"AB",  15  => x"76",

        -- x = 1
        16  => x"CA",  17  => x"82",  18  => x"C9",  19  => x"7D",
        20  => x"FA",  21  => x"59",  22  => x"47",  23  => x"F0",
        24  => x"AD",  25  => x"D4",  26  => x"A2",  27  => x"AF",
        28  => x"9C",  29  => x"A4",  30  => x"72",  31  => x"C0",

        -- x = 2
        32  => x"B7",  33  => x"FD",  34  => x"93",  35  => x"26",
        36  => x"36",  37  => x"3F",  38  => x"F7",  39  => x"CC",
        40  => x"34",  41  => x"A5",  42  => x"E5",  43  => x"F1",
        44  => x"71",  45  => x"D8",  46  => x"31",  47  => x"15",

        -- x = 3
        48  => x"04",  49  => x"C7",  50  => x"23",  51  => x"C3",
        52  => x"18",  53  => x"96",  54  => x"05",  55  => x"9A",
        56  => x"07",  57  => x"12",  58  => x"80",  59  => x"E2",
        60  => x"EB",  61  => x"27",  62  => x"B2",  63  => x"75",

        -- x = 4
        64  => x"09",  65  => x"83",  66  => x"2C",  67  => x"1A",
        68  => x"1B",  69  => x"6E",  70  => x"5A",  71  => x"A0",
        72  => x"52",  73  => x"3B",  74  => x"D6",  75  => x"B3",
        76  => x"29",  77  => x"E3",  78  => x"2F",  79  => x"84",

        -- x = 5
        80  => x"53",  81  => x"D1",  82  => x"00",  83  => x"ED",
        84  => x"20",  85  => x"FC",  86  => x"B1",  87  => x"5B",
        88  => x"6A",  89  => x"CB",  90  => x"BE",  91  => x"39",
        92  => x"4A",  93  => x"4C",  94  => x"58",  95  => x"CF",

        -- x = 6
        96  => x"D0",  97  => x"EF",  98  => x"AA",  99  => x"FB",
        100 => x"43",  101 => x"4D",  102 => x"33",  103 => x"85",
        104 => x"45",  105 => x"F9",  106 => x"02",  107 => x"7F",
        108 => x"50",  109 => x"3C",  110 => x"9F",  111 => x"A8",

        -- x = 7
        112 => x"51",  113 => x"A3",  114 => x"40",  115 => x"8F",
        116 => x"92",  117 => x"9D",  118 => x"38",  119 => x"F5",
        120 => x"BC",  121 => x"B6",  122 => x"DA",  123 => x"21",
        124 => x"10",  125 => x"FF",  126 => x"F3",  127 => x"D2",

        -- x = 8
        128 => x"CD",  129 => x"0C",  130 => x"13",  131 => x"EC",
        132 => x"5F",  133 => x"97",  134 => x"44",  135 => x"17",
        136 => x"C4",  137 => x"A7",  138 => x"7E",  139 => x"3D",
        140 => x"64",  141 => x"5D",  142 => x"19",  143 => x"73",

        -- x = 9
        144 => x"60",  145 => x"81",  146 => x"4F",  147 => x"DC",
        148 => x"22",  149 => x"2A",  150 => x"90",  151 => x"88",
        152 => x"46",  153 => x"EE",  154 => x"B8",  155 => x"14",
        156 => x"DE",  157 => x"5E",  158 => x"0B",  159 => x"DB",

        -- x = A
        160 => x"E0",  161 => x"32",  162 => x"3A",  163 => x"0A",
        164 => x"49",  165 => x"06",  166 => x"24",  167 => x"5C",
        168 => x"C2",  169 => x"D3",  170 => x"AC",  171 => x"62",
        172 => x"91",  173 => x"95",  174 => x"E4",  175 => x"79",

        -- x = B
        176 => x"E7",  177 => x"C8",  178 => x"37",  179 => x"6D",
        180 => x"8D",  181 => x"D5",  182 => x"4E",  183 => x"A9",
        184 => x"6C",  185 => x"56",  186 => x"F4",  187 => x"EA",
        188 => x"65",  189 => x"7A",  190 => x"AE",  191 => x"08",

        -- x = C
        192 => x"BA",  193 => x"78",  194 => x"25",  195 => x"2E",
        196 => x"1C",  197 => x"A6",  198 => x"B4",  199 => x"C6",
        200 => x"E8",  201 => x"DD",  202 => x"74",  203 => x"1F",
        204 => x"4B",  205 => x"BD",  206 => x"8B",  207 => x"8A",

        -- x = D
        208 => x"70",  209 => x"3E",  210 => x"B5",  211 => x"66",
        212 => x"48",  213 => x"03",  214 => x"F6",  215 => x"0E",
        216 => x"61",  217 => x"35",  218 => x"57",  219 => x"B9",
        220 => x"86",  221 => x"C1",  222 => x"1D",  223 => x"9E",

        -- x = E
        224 => x"E1",  225 => x"F8",  226 => x"98",  227 => x"11",
        228 => x"69",  229 => x"D9",  230 => x"8E",  231 => x"94",
        232 => x"9B",  233 => x"1E",  234 => x"87",  235 => x"E9",
        236 => x"CE",  237 => x"55",  238 => x"28",  239 => x"DF",

        -- x = F
        240 => x"8C",  241 => x"A1",  242 => x"89",  243 => x"0D",
        244 => x"BF",  245 => x"E6",  246 => x"42",  247 => x"68",
        248 => x"41",  249 => x"99",  250 => x"2D",  251 => x"0F",
        252 => x"B0",  253 => x"54",  254 => x"BB",  255 => x"16"
    );



    pure function vector_to_state(
        x : std_logic_vector(127 downto 0)
    ) return state_type is

    variable y : state_type;

    begin

        for i in 0 to ((x'length)/8-1) loop
            y(i mod 4, i / 4) :=
                x(127 - 8*i downto 120 - 8*i);
        end loop;

    return y;

    end function vector_to_state;

    pure function state_to_vector(
        x : state_type
    ) return std_logic_vector is

    variable y : std_logic_vector(127 downto 0);

    begin

        for i in 0 to ((y'length)/8-1) loop
            y(127 - 8*i downto 120 - 8*i):= 
                x(i mod 4, i / 4) ;
        end loop;

    return y;
    
    end function state_to_vector;
        
    


    ----------------------------------------------------------------
    -- GF(2^8) multiplication by 2
    --
    -- AES reduction polynomial:
    --
    -- x^8 + x^4 + x^3 + x + 1
    --
    -- Reduction constant:
    -- 00011011 = 0x1B
    ----------------------------------------------------------------
    pure function gf_mult_by2(
        x : std_logic_vector(7 downto 0)
    ) return std_logic_vector is

        variable y : std_logic_vector(7 downto 0);

    begin

        y(7) := x(6);
        y(6) := x(5);
        y(5) := x(4);
        y(4) := x(3) xor x(7);
        y(3) := x(2) xor x(7);
        y(2) := x(1);
        y(1) := x(0) xor x(7);
        y(0) := x(7);

        return y;

    end function gf_mult_by2;

    pure function gf_mult_by3(
        x : std_logic_vector(7 downto 0)
    ) return std_logic_vector is
    begin

        return gf_mult_by2(x) xor x;

    end function gf_mult_by3;


    ----------------------------------------------------------------
    -- AES MixColumns
    --
    -- Input:
    --
    --   x(31:24) = a0
    --   x(23:16) = a1
    --   x(15:8)  = a2
    --   x(7:0)   = a3
    --
    -- Output:
    --
    --   r0 = 2*a0 + 3*a1 + a2 + a3
    --   r1 = a0 + 2*a1 + 3*a2 + a3
    --   r2 = a0 + a1 + 2*a2 + 3*a3
    --   r3 = 3*a0 + a1 + a2 + 2*a3
    --
    -- All arithmetic is in GF(2^8).
    ----------------------------------------------------------------
    pure function mix_column(
        x : std_logic_vector(31 downto 0)
    ) return std_logic_vector is
 
        variable a0 : std_logic_vector(7 downto 0);
        variable a1 : std_logic_vector(7 downto 0);
        variable a2 : std_logic_vector(7 downto 0);
        variable a3 : std_logic_vector(7 downto 0);

        variable t  : std_logic_vector(7 downto 0);

        variable r0 : std_logic_vector(7 downto 0);
        variable r1 : std_logic_vector(7 downto 0);
        variable r2 : std_logic_vector(7 downto 0);
        variable r3 : std_logic_vector(7 downto 0);

    begin

        -- Extract the four AES bytes
        a0 := x(31 downto 24);
        a1 := x(23 downto 16);
        a2 := x(15 downto 8);
        a3 := x(7 downto 0);

        -- XOR of all four bytes
        t := a0 xor a1 xor a2 xor a3;

        -- MixColumns
        r0 := a0 xor gf_mult_by2(a0 xor a1) xor t;
        r1 := a1 xor gf_mult_by2(a1 xor a2) xor t;
        r2 := a2 xor gf_mult_by2(a2 xor a3) xor t;
        r3 := a3 xor gf_mult_by2(a3 xor a0) xor t;

        -- Reassemble the 32-bit column
        return r0 & r1 & r2 & r3;

    end function mix_column;





    pure function shift_rows(
        x : state_type
    ) return state_type is

        variable y : state_type;

    begin
        y :=x;
        for i in 1 to 3 loop
            for j in 0 to 3 loop
                y(i,j) := x(i,(j+i) mod 4);
            end loop;
        end loop;

        return y;

    end function shift_rows;


    

    pure function rot_word(
        x : std_logic_vector (31 downto 0)
    ) return std_logic_vector is
    begin
        return x(23 downto 0) & x(31 downto 24);
    end function rot_word;


    pure function add_round_key(
        x: state_type
        y: std_logic_vector (127 downto 0)
    ) return state_type is

    begin

    return  vector_to_state(y xor state_to_vector(x));
    end function add_round_key;


    pure function round_exp(
        closeKeyW   : std_logic_vector(31 downto 0);   -- w[i-1]
        farKeyW     : std_logic_vector(31 downto 0);   -- w[i-8]
        newKeyIndex : integer                          -- i
    ) return std_logic_vector is

        variable keyW_o : std_logic_vector(31 downto 0);

    begin
        if newKeyIndex mod 8 = 0 then
            keyW_o := sub_word(rot_word(closeKeyW))
                    xor (RCON(newKeyIndex/8) & x"000000");
        elsif newKeyIndex mod 8 = 4 then
            keyW_o := sub_word(closeKeyW);
        else
            keyW_o := closeKeyW;
        end if;

        return keyW_o xor farKeyW;
    end function round_exp;



        -- The LUT S-box: one byte in, one byte out
    pure function sbox(x : std_logic_vector(7 downto 0))
        return std_logic_vector is
    begin
        return SBOX_TABLE(to_integer(unsigned(x)));
    end function sbox;

    -- Key schedule: S-box on the 4 bytes of a word
    pure function sub_word(x : std_logic_vector(31 downto 0))
        return std_logic_vector is
    begin
        return sbox(x(31 downto 24)) &
               sbox(x(23 downto 16)) &
               sbox(x(15 downto 8))  &
               sbox(x(7 downto 0));
    end function sub_word;

    -- Cipher: S-box on all 16 bytes of the state
    pure function sub_bytes(s : state_type)
        return state_type is
        variable y : state_type;
    begin
        for r in 0 to 3 loop
            for c in 0 to 3 loop
                y(r, c) := sbox(s(r, c));
            end loop;
        end loop;
        return y;
    end function sub_bytes;


    pure function key_expansion(key : std_logic_vector(255 downto 0))
        return word_array is
        variable w : word_array;
    begin
        for i in 0 to 7 loop
            w(i) := key(255 - 32*i downto 224 - 32*i);
        end loop;
        for i in 8 to 59 loop
            w(i) := round_exp(w(i-1), w(i-8), i);
        end loop;
        return w;
    end function;
    

end package body AESpkg;