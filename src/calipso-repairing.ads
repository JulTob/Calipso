--  Find what does not fit and fix it.
--
--  After collapsing, each letter can be examined: "if I hide you, would your
--  neighbours have guessed you?". If the answer is "not even close", that letter
--  is surprising: the text does not fit there.
--
--     Surprise : how strange a letter looks to its neighbours (in nats).
--     Tension  : sum of the surprise that goes over what is tolerable, in the
--                zone the model has touched. Tension 0 = "everything fits".
--
--  Relaxing the canvas = repeat: find the most surprising letter, reopen its
--  surroundings and collapse again. If the same room does not improve it, try
--  WIDENING: put new cells in there. So the text grows only where it is needed.

with Calipso.Canvases;
with Calipso.Oracles;
with Calipso.Random_Sources;

package Calipso.Repairing is

    type Settings is record
        Tolerance   : Long_Float := 4.0;
        --# Tolerable surprise per letter, in nats. 4 nats = "happens 1 time in 55".
        Max_Rounds  : Natural := 40;
        Radius      : Natural := 4;
        --# When reopening, how many cells on each side of the focus become holes again.
        Extra_Cells : Positive := 3;
        --# When widening, how many new cells are put in.
        Max_Length  : Positive := 2_000;
        Can_Grow    : Boolean := True;
        end record;

    Default_Settings : constant Settings := (others => <>);

    type Report is record
        Rounds        : Natural := 0;
        Reopenings    : Natural := 0;
        Widenings     : Natural := 0;
        Final_Tension : Long_Float := 0.0;
        end record;

    function Surprise_At (
            Board    : in Canvases.Canvas;
            Model    : in Oracles.Oracle'Class;
            Position : in Positive
            ) return Long_Float
        with Pre => Position <= Canvases.Length (Board) and then not Canvases.Is_Blank (Board, Position);

    function Tension (
            Board     : in Canvases.Canvas;
            Model     : in Oracles.Oracle'Class;
            Tolerance : in Long_Float
            ) return Long_Float
        with Post => Tension'Result >= 0.0;

    function Most_Surprising_Cell (
            Board : in Canvases.Canvas;
            Model : in Oracles.Oracle'Class
            ) return Natural;
    --# The measured cell that surprises the most. 0 if there is none to measure.

    procedure Relax (
            Board   : in out Canvases.Canvas;
            Model   : in     Oracles.Oracle'Class;
            Dice    : in out Random_Sources.Generator;
            Outcome :    out Report;
            Options : in     Settings := Default_Settings
            );
    --# Given letters never change. The final tension is never higher than the initial one.

    end Calipso.Repairing;
