--  The contract of any "brain".
--
--  An oracle answers a single question:
--
--     "Looking at what is around, which letter do you think goes in this cell?"
--
--  and answers with a distribution (an opinion with doubts, not a letter).
--
--  The collapse engine only knows this contract. One brain is a count
--  table; another one learns its numbers. The engine does not change.

with Calipso.Canvases;
with Calipso.Distributions;

package Calipso.Oracles is

    type Oracle is interface;

    function Alphabet_Size (
            Self : in Oracle
            ) return Symbol is abstract;

    function Reach (
            Self : in Oracle
            ) return Natural is abstract;
    --# How many cells away a letter can influence the opinion about another.
    --# The engine uses it to know which opinions go out of date when a cell collapses.

    function Opinion (
            Self     : in Oracle;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution is abstract
        with
            Pre'Class  => Position <= Canvases.Length (Board),
            Post'Class => Opinion'Result.Size = Alphabet_Size (Self);
    --# Opinion about cell Position looking ONLY at its neighbours, never at the cell itself.
    --# That is why it works just as well to fill a hole as to examine a letter already placed.

    end Calipso.Oracles;
