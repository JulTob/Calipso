--  The dial: how sure are we that a cell already holds the right symbol?
--
--  There are two ways of saying it. They are the same dial read on two scales:
--
--     Certainty          0 .. 1   the chance that the symbol is right.
--                                 1 = it is right.   0 = it is wrong.
--                                 "No idea" is 1/N for an alphabet of N symbols:
--                                 it moves when the alphabet changes size.
--
--     Signed_Certainty  -1 .. 1   +1 = it is right.  -1 = it is wrong.
--                                 0 = no idea, whatever the size of the alphabet.
--
--  From 0 up, the signed scale walks from "no idea" to "right". From 0 down, it
--  walks from "no idea" to "wrong". Each half is a straight line.
--
--  It mirrors reference/calipso_ref/certainties.py.

package Calipso.Certainties is

    type Certainty is new Long_Float range 0.0 .. 1.0;

    type Signed_Certainty is new Long_Float range -1.0 .. 1.0;

    Surely_Right : constant Signed_Certainty := 1.0;
    No_Idea      : constant Signed_Certainty := 0.0;
    Surely_Wrong : constant Signed_Certainty := -1.0;

    function Chance_Level (
            Size : in Symbol
            ) return Certainty
        with Pre => Size >= 2;
    --# The certainty that means "no idea": one in Size.

    function Certainty_Of (
            Signed : in Signed_Certainty;
            Size   : in Symbol
            ) return Certainty
        with Pre => Size >= 2;
    --# The signed dial, read as a chance. Size is how many symbols the alphabet has.

    function Signed_Of (
            Plain : in Certainty;
            Size  : in Symbol
            ) return Signed_Certainty
        with Pre => Size >= 2;
    --# A chance, read on the signed dial.

    end Calipso.Certainties;
