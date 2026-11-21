--  The catalogue of neuron models.
--
--  The one place that knows every kind of neuron. A new kind of neuron is a
--  new package plus one line here.
--
--  Names that can be used in a recipe, with the sizes each one accepts:
--
--     bias                      starting points of each letter; looks at nothing
--     position:REACH            what letter is at each exact distance
--     presence:REACH            what letters are around, wherever they are
--     harmonic:REACH:WAVES      waves over distance (Fourier)
--     decay:REACH:SPEEDS        fading with distance at several speeds (Laplace)
--     counting:LONGEST          the table of fragment counts
--     memory:COUNTERS:LONGEST   the same table with a fixed size (bounded memory)
--
--  Every size can be left out, and the usual one is then taken: "position" is
--  "position:12". Larger sizes make a larger brain from the same code:
--  "position:24+decay:24:8+memory:16777216".
--
--     REACH    how many letters each way the neuron looks
--     WAVES    how many pairs of waves; SPEEDS: how many fading speeds
--     LONGEST  the longest fragment that is counted
--     COUNTERS how many counters the bounded memory has

with Calipso.Neurons;

package Calipso.Neuron_Kinds is

    Most_Reach    : constant Positive := 512;
    Most_Detail   : constant Positive := 64;
    Most_Longest  : constant Positive := 32;
    Most_Counters : constant Positive := Positive'Last;
    --# The largest sizes a recipe may ask for.

    Recipe_Error : exception;

    function Made (
            Name         : in String;
            Letter_Count : in Symbol
            ) return Neurons.Neuron'Class;
    --# A blank neuron of the kind and sizes this recipe name asks for.
    --# Raises Recipe_Error if the name is not in the catalogue or a size is wrong.

    function Blank_Of_Kind (
            Kind : in String
            ) return Neurons.Neuron'Class;
    --# An empty neuron of the package that saved under this word, ready to Load.

    end Calipso.Neuron_Kinds;
