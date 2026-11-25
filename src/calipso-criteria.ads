--  How to decide which hole collapses next.
--
--  A criterion looks at one hole and says how READY it is to collapse, from
--  0 (not at all) to 1 (completely). The engine always collapses the readiest
--  hole. Neither of the first two criteria cares where the hole is: the order
--  of collapse comes from the content, not from the position.
--
--     Certainty : 1 minus the doubt of the opinion. This is the "collapse index":
--                 1 = one letter is certain, 0 = all letters equally possible.
--     Agreement : how much the neurons of a brain, each asked alone, share the
--                 same bets. 1 = they all say the same, 0 = nothing in common.
--     Leftmost  : readier the further left. It reproduces writing left to right,
--                 and is here to compare against.
--     Mixed     : several criteria, each with a weight.

with Ada.Containers.Indefinite_Vectors;

with Calipso.Canvases;
with Calipso.Numbers;
with Calipso.Oracles;

package Calipso.Criteria is

    type Criterion is interface;

    function Readiness (
            Self     : in Criterion;
            Board    : in Canvases.Canvas;
            Model    : in Oracles.Oracle'Class;
            Position : in Positive
            ) return Long_Float is abstract;

    function Same (
            Left  : in Criterion'Class;
            Right : in Criterion'Class
            ) return Boolean;
    --# Needed by the list of criteria that a mix keeps.

    type Certainty is new Criterion with null record;

    overriding function Readiness (
            Self     : in Certainty;
            Board    : in Canvases.Canvas;
            Model    : in Oracles.Oracle'Class;
            Position : in Positive
            ) return Long_Float;

    type Agreement is new Criterion with null record;

    overriding function Readiness (
            Self     : in Agreement;
            Board    : in Canvases.Canvas;
            Model    : in Oracles.Oracle'Class;
            Position : in Positive
            ) return Long_Float;
    --# With a model that is not a brain, or a brain with fewer than two neurons
    --# that look around, there is nothing to compare: it answers as Certainty does.

    type Leftmost is new Criterion with null record;

    overriding function Readiness (
            Self     : in Leftmost;
            Board    : in Canvases.Canvas;
            Model    : in Oracles.Oracle'Class;
            Position : in Positive
            ) return Long_Float;

    type Mixed is new Criterion with private;

    procedure Add_Part (
            Self   : in out Mixed;
            Part   : in     Criterion'Class;
            Weight : in     Long_Float := 1.0
            );

    overriding function Readiness (
            Self     : in Mixed;
            Board    : in Canvases.Canvas;
            Model    : in Oracles.Oracle'Class;
            Position : in Positive
            ) return Long_Float;

private

    package Part_Lists is new Ada.Containers.Indefinite_Vectors (
            Index_Type   => Positive,
            Element_Type => Criterion'Class,
            "="          => Same
            );

    type Mixed is new Criterion with record
        Parts   : Part_Lists.Vector;
        Weights : Numbers.Real_Row;
        end record;

    end Calipso.Criteria;
