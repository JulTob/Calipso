--  The collapse engine.
--
--  Loop (the same as in the "Wave Function Collapse" algorithm):
--
--     1. Observe   : find the hole there is LEAST doubt about.
--     2. Collapse  : decide its letter by rolling a dice loaded with the opinion.
--     3. Propagate : the opinions of its neighbours have changed; recompute them.
--
--  and repeat until no holes are left.
--
--  The engine does not know which brain it uses: it only knows the Oracle contract.

with Calipso.Canvases;
with Calipso.Criteria;
with Calipso.Oracles;
with Calipso.Random_Sources;

package Calipso.Collapsing is

    type Visiting_Order is (Most_Certain_First, Left_To_Right, At_Random);
    --# Order in which holes are visited. The first one is the collapse proper;
    --# the other two are there so that we can compare.

    type Choice_Rule is (By_Chance, Always_Most_Likely);
    --# How the letter is decided: by drawing lots from the opinion, or always taking the most likely.

    procedure Collapse_All (
            Board    : in out Canvases.Canvas;
            Model    : in     Oracles.Oracle'Class;
            Dice     : in out Random_Sources.Generator;
            Order    : in     Visiting_Order := Most_Certain_First;
            Rule     : in     Choice_Rule := By_Chance;
            Observer : access procedure (
                    Current  : in Canvases.Canvas;
                    Position : in Positive
                    ) := null
            )
        with Post => Canvases.Blank_Count (Board) = 0;
    --# Fills every hole of the canvas.
    --# Observer, if given, is called after each collapsed cell (to draw the process).

    procedure Collapse_By (
            Board    : in out Canvases.Canvas;
            Model    : in     Oracles.Oracle'Class;
            Dice     : in out Random_Sources.Generator;
            Guide    : in     Criteria.Criterion'Class;
            Rule     : in     Choice_Rule := By_Chance;
            Observer : access procedure (
                    Current  : in Canvases.Canvas;
                    Position : in Positive
                    ) := null
            )
        with Post => Canvases.Blank_Count (Board) = 0;
    --# The same loop as Collapse_All, but the order is decided by a criterion
    --# that can be swapped: the readiest hole collapses first.

    end Calipso.Collapsing;
