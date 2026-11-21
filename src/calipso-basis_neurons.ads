--  Neurons that weigh neighbours by distance.
--
--  Every known neighbour votes with a row of points that depends on the letter
--  it holds. What changes from one kind to another is HOW the distance to the
--  hole is measured. Each way of measuring is a small set of curves over
--  distance (a "basis"), and there is one table of votes per curve:
--
--     By_Position : one curve per exact distance. "What is 3 cells to my left?"
--                   Sharp, but knows nothing about "somewhere nearby".
--
--     By_Harmonic : waves over the window, as in a Fourier series. The first
--                   curve is flat: it ignores position altogether ("this letter
--                   is around"). Each further pair of waves adds a finer sense
--                   of where. With no waves at all it is the "presence" neuron.
--
--     By_Decay    : curves that fade with distance, at several speeds, as in a
--                   Laplace transform. Fast fading sees only the next letter;
--                   slow fading sees far, blurred. One set looks left, one right.

with Ada.Text_IO;

with Calipso.Canvases;
with Calipso.Distributions;
with Calipso.Neurons;
with Calipso.Numbers;

package Calipso.Basis_Neurons is

    type Basis_Kind is (By_Position, By_Harmonic, By_Decay);

    type Basis_Neuron is new Neurons.Neuron with private;

    procedure Prepare (
            Self         : in out Basis_Neuron;
            Letter_Count : in     Symbol;
            Measure      : in     Basis_Kind;
            Reach        : in     Positive;
            Detail       : in     Natural
            );
    --# Leaves the neuron blank: its curves drawn, all its votes at 0.
    --# Detail: for By_Harmonic, how many pairs of waves; for By_Decay, how many
    --# fading speeds; for By_Position it is not used.

    function Curve_Height (
            Self   : in Basis_Neuron;
            Curve  : in Positive;
            Offset : in Integer
            ) return Long_Float;
    --# The height of one curve at one distance. Offered so that the curves can be inspected.

    overriding function Name (
            Self : in Basis_Neuron
            ) return String;

    overriding function Kind (
            Self : in Basis_Neuron
            ) return String;

    overriding function Reach (
            Self : in Basis_Neuron
            ) return Natural;

    overriding procedure Add_Scores (
            Self     : in     Basis_Neuron;
            Board    : in     Canvases.Canvas;
            Position : in     Positive;
            Strength : in     Long_Float;
            Scores   : in out Distributions.Score_Array
            );

    overriding procedure Learn_From_Cell (
            Self     : in out Basis_Neuron;
            Board    : in     Canvases.Canvas;
            Position : in     Positive;
            Errors   : in     Distributions.Score_Array;
            Step     : in     Long_Float
            );

    overriding procedure Save (
            Self : in Basis_Neuron;
            File : in Ada.Text_IO.File_Type
            );

    overriding procedure Load (
            Self : in out Basis_Neuron;
            File : in     Ada.Text_IO.File_Type
            );

private

    type Basis_Neuron is new Neurons.Neuron with record
        Letter_Count : Symbol := 1;
        Vote_Reach   : Positive := 1;
        Measure      : Basis_Kind := By_Position;
        Detail       : Natural := 0;
        Curve_Count  : Natural := 0;
        Basis        : Numbers.Real_Row;
        --# Basis (curve, distance): the height of each curve at each distance. See Basis_Slot.
        Votes        : Numbers.Real_Row;
        --# Votes (curve, neighbour letter, candidate letter), all in one long row. See Vote_Slot.
        end record;

    end Calipso.Basis_Neurons;
