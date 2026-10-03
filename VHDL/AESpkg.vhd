library ieee;
use ieee.std_logic_1164.all;

package aes_functions is

    subtype state_type is array (3 downto 0, 3 downto 0) of STD_LOGIC_VECTOR (7 downto 0);

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

end package aes_functions;


package body aes_functions is

    

    pure function vector_to_state(
        x : std_logic_vector(127 downto 0)
    ) return state _type is

    variable y : state_type;

    begin

        for i in 0 to ((x'length)/8-)1 loop
            y(i mod 4, i / 4) :=
                x(127 - 8*i downto 120 - 8*i);
        end loop;

    return y;

    end function vector_to_state;

    pure function state_to_vector(
        x : state_type;
    ) return std_logic_vector is

    variable y : std_logic_vector(127 downto 0)

    begin

        for i in 0 to ((y'length)/8-)1 loop
            y(127 - 8*i downto 120 - 8*i):= 
                x(i mod 4, i / 4) ;
        end loop;
    
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
        x : state_type;
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

    end function mix_columns;

    pure function rot_word(
        x : std_logic_vector (31 downto 0)
    ) return std_logic_vector is
    begin
        return x(23 downto 0) & x(31 downto 24);
    end function rot_word;

    pure function sub_bytes(
        x:
    )

end package body aes_functions;