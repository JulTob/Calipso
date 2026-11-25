--  A brain that remembers what the cell had.
--
--  A boxed oracle obeys hard rules: a symbol is allowed or it is not. An anchored
--  oracle obeys a soft one: "this cell had the symbol H, and I am this sure it was
--  right". The brain's opinion and that memory are multiplied together:
--
--     sure = 1      the cell keeps H whatever the brain thinks      (like a Given cell)
--     sure = 1/N    the memory says nothing, the brain decides      (like a Blank cell)
--     sure = 0      anything but H                                  ("surely wrong")
--
--  In between, the certainty is a price: how strongly the neighbours must disagree
--  before the cell changes.
--
--  It mirrors reference/calipso_ref/anchored_oracles.py.

with Ada.Containers.Vectors;

with Calipso.Canvases;
with Calipso.Certainties;
with Calipso.Distributions;
with Calipso.Oracles;

package Calipso.Anchored_Oracles is

    type Anchor is record
        Is_Free : Boolean := True;
        --# Free: nothing is remembered for this cell, the opinion passes untouched.
        Held    : Symbol := Unknown;
        --# The symbol the cell had.
        Sure    : Certainties.Certainty := 1.0;
        --# The chance that Held is right.
        end record;

    Free_Anchor : constant Anchor := (Is_Free => True, Held => Unknown, Sure => 1.0);

    function Anchor_Of (
            Held : in Symbol;
            Sure : in Certainties.Certainty
            ) return Anchor;

    function Anchor_Of (
            Held   : in Symbol;
            Signed : in Certainties.Signed_Certainty;
            Size   : in Symbol
            ) return Anchor
        with Pre => Size >= 2;
    --# The same anchor, said on the scale from -1 to 1. Size is how many symbols the alphabet has.

    package Anchor_Vectors is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Anchor
            );

    subtype Anchor_List is Anchor_Vectors.Vector;
    --# One anchor for each cell of a canvas. A cell beyond the end of the list is free.

    function Pulled (
            Belief : in Distributions.Distribution;
            Toward : in Anchor
            ) return Distributions.Distribution
        with Post => Pulled'Result.Size = Belief.Size;
    --# The brain's opinion and the memory of the cell, multiplied symbol by symbol.

    type Anchored_Oracle (
            Inner : not null access constant Oracles.Oracle'Class
            ) is new Oracles.Oracle with record
        Anchors : Anchor_List;
        end record;
    --# Inner is the brain that gives the opinions. It is looked at, never copied.

    overriding function Alphabet_Size (
            Self : in Anchored_Oracle
            ) return Symbol;

    overriding function Reach (
            Self : in Anchored_Oracle
            ) return Natural;

    overriding function Opinion (
            Self     : in Anchored_Oracle;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution;

    end Calipso.Anchored_Oracles;
