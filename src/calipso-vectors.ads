--  Lists of numbers with an algebra.
--
--  A word can be described by a list of numbers (how often each kind stands
--  beside it). Then two words can be compared like two arrows:
--
--     dot product   multiply them place by place and add
--     length        how long the arrow is
--     cosine        the dot product of the two arrows made of length 1:
--                   +1 they point the same way, 0 they have nothing in common,
--                   -1 they point opposite ways
--
--  The complex product is for a vector made of two halves that mean different
--  things (what stands BEFORE a word, and what stands AFTER it). Each vector is
--  read as  first half + i * second half :
--
--     real part        the plain dot product: how alike the two are
--     imaginary part   first half of one against second half of the other, both
--                      ways, subtracted. Swap the two vectors and it changes
--                      sign: it holds ORDER, which the plain dot product forgets.
--
--  It mirrors reference/calipso_ref/vectors.py.

with Ada.Numerics.Long_Complex_Types;

package Calipso.Vectors is

    type Vector is array (Positive range <>) of Long_Float;

    subtype Complex is Ada.Numerics.Long_Complex_Types.Complex;

    function "+" (
            Left  : in Vector;
            Right : in Vector
            ) return Vector
        with Pre => Left'Length = Right'Length;

    function "-" (
            Left  : in Vector;
            Right : in Vector
            ) return Vector
        with Pre => Left'Length = Right'Length;

    function "*" (
            Scale : in Long_Float;
            Item  : in Vector
            ) return Vector;

    function "*" (
            Left  : in Vector;
            Right : in Vector
            ) return Long_Float
        with Pre => Left'Length = Right'Length;
    --# The dot product.

    function Length (
            Item : in Vector
            ) return Long_Float;

    function Unit (
            Item : in Vector
            ) return Vector;
    --# The same direction with length 1. An arrow of length 0 has no direction: it stays as it is.

    function Cosine (
            Left  : in Vector;
            Right : in Vector
            ) return Long_Float
        with
            Pre  => Left'Length = Right'Length,
            Post => Cosine'Result in -1.0 .. 1.0;
    --# 0 when either arrow has length 0.

    function Complex_Product (
            Left  : in Vector;
            Right : in Vector
            ) return Complex
        with Pre => Left'Length = Right'Length and then Left'Length mod 2 = 0;

    function Turn (
            Left  : in Vector;
            Right : in Vector
            ) return Long_Float
        with Pre => Left'Length = Right'Length and then Left'Length mod 2 = 0;
    --# The angle of the complex product, in degrees: near 0 the two are alike,
    --# near +90 or -90 one stands where the other's neighbours stand.

    end Calipso.Vectors;
