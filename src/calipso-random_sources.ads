--  Repeatable randomness.
--
--  A very simple generator of our own. With the same seed it always gives
--  the same numbers, here and in the Python reference. So any
--  result can be repeated and checked.

with Interfaces;

package Calipso.Random_Sources is

    subtype Unit_Fraction is Long_Float range 0.0 .. 1.0;

    type Generator is private;

    function Seeded (
            Seed : in Natural
            ) return Generator;

    procedure Draw_Unit (
            Source : in out Generator;
            Unit   :    out Unit_Fraction
            )
        with Post => Unit < 1.0;
    --# Draws a number in [0, 1) and advances the generator.
    --# It is a procedure and not a function because it changes the generator:
    --# this way the effect is visible at every call.

    procedure Draw_Index (
            Source : in out Generator;
            Below  : in     Positive;
            Index  :    out Natural
            )
        with Post => Index < Below;
    --# Draws an integer in 0 .. Below - 1.

private

    type Generator is record
        State : Interfaces.Unsigned_64 := 0;
        end record;

    end Calipso.Random_Sources;
