--  A brain that obeys the level above.
--
--  The level above does not choose letters. It says, cell by cell, which letters
--  are ALLOWED ("only small letters here", "only digits there"). This oracle asks
--  another one for its opinion and removes from it what is not allowed.
--
--  It is an Oracle like any other, so the collapse engine uses it without knowing.
--
--  It mirrors reference/calipso_ref/boxed_oracles.py.

with Ada.Containers.Vectors;

with Calipso.Canvases;
with Calipso.Distributions;
with Calipso.Oracles;

package Calipso.Boxed_Oracles is

    type Permission is array (Symbol) of Boolean;
    --# Permission (S): may symbol S be written in the cell?

    type Cell_Rule is record
        Is_Free : Boolean := True;
        --# Free: no rule for this cell, the opinion passes untouched.
        Allowed : Permission := (others => False);
        end record;

    Free_Rule : constant Cell_Rule := (Is_Free => True, Allowed => (others => False));

    function Rule_Of (
            Allowed : in Permission
            ) return Cell_Rule;
    --# The rule "only these symbols".

    package Rule_Vectors is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Cell_Rule
            );

    subtype Rule_List is Rule_Vectors.Vector;
    --# One rule for each cell of a canvas. A cell beyond the end of the list is free.

    function Kept_Part (
            Belief  : in Distributions.Distribution;
            Allowed : in Permission
            ) return Distributions.Distribution
        with Post => Kept_Part'Result.Size = Belief.Size;
    --# The opinion with what is not allowed taken out, and the rest scaled to add up to 1.

    type Boxed_Oracle (
            Inner : not null access constant Oracles.Oracle'Class
            ) is new Oracles.Oracle with record
        Rules : Rule_List;
        end record;
    --# Inner is the brain that gives the opinions. It is looked at, never copied:
    --# a brain can hold millions of counts.

    overriding function Alphabet_Size (
            Self : in Boxed_Oracle
            ) return Symbol;

    overriding function Reach (
            Self : in Boxed_Oracle
            ) return Natural;

    overriding function Opinion (
            Self     : in Boxed_Oracle;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution;

    end Calipso.Boxed_Oracles;
