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

    ---------------------------------------------------------------------------
    --  The third scale, and the curved model of the dial.
    --
    --     Evidence   any number, in nats.  0 = no idea.  Positive = for.  Negative = against.
    --                Evidence from two sources that do not depend on each other ADDS.
    --                This is the scale to calculate with.
    --
    --  The other two scales are the evidence, squeezed into a fixed range:
    --
    --     signed certainty = tanh (evidence / 2)                          between -1 and 1
    --     certainty        = sigmoid (evidence + the evidence of pure chance)  between 0 and 1
    --
    --  tanh and the sigmoid are the same curve drawn on two different rulers.

    type Evidence is new Long_Float;

    Most_Evidence : constant Evidence := 36.0;
    --# Beyond this a chance cannot be told from 0 or 1 with the numbers the machine keeps.

    type Dial_Model is (Straight, Curved);
    --# Two models for reading the signed dial as a chance:
    --#    Straight: each half of the dial is a straight line.
    --#    Curved  : the dial is the tanh of half the evidence.

    function Signed_From (
            Weight : in Evidence
            ) return Signed_Certainty;
    --# tanh (Weight / 2).

    function To_Evidence (
            Signed : in Signed_Certainty
            ) return Evidence;
    --# The evidence a position of the signed dial stands for. The two ends give Most_Evidence.

    function To_Evidence (
            Plain : in Certainty;
            Size  : in Symbol
            ) return Evidence
        with Pre => Size >= 2;
    --# How far a chance is from pure chance, as evidence.

    function Certainty_From (
            Weight : in Evidence;
            Size   : in Symbol
            ) return Certainty
        with Pre => Size >= 2;
    --# The sigmoid: the chance that this much evidence makes of pure chance.

    function Certainty_Of (
            Signed : in Signed_Certainty;
            Size   : in Symbol;
            Model  : in Dial_Model
            ) return Certainty
        with Pre => Size >= 2;
    --# The signed dial read as a chance, by the model asked for. The two ends are exact in both.

    function "&" (
            Left  : in Signed_Certainty;
            Right : in Signed_Certainty
            ) return Signed_Certainty;
    --# Two signed certainties about the same thing, from two sources, made into one:
    --# the sum of their evidence, read back on the signed dial.
    --# No_Idea changes nothing; opposite certainties cancel.

    end Calipso.Certainties;
