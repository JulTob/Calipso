--  The catalogue of neuron models.
--
--  The one place that knows every kind of neuron. A new kind of neuron is a
--  new package plus one line here.
--
--  Names that can be used in a recipe:
--
--     bias      starting points of each letter; looks at nothing
--     position  what letter is at each exact distance
--     presence  what letters are around, wherever they are
--     harmonic  waves over distance (Fourier)
--     decay     fading with distance at several speeds (Laplace)
--     counting  the table of fragment counts
--     memory    the same table with a fixed size (bounded memory)

with Calipso.Neurons;

package Calipso.Neuron_Kinds is

    Default_Reach  : constant Positive := 12;
    Default_Waves  : constant Natural := 4;
    Default_Speeds : constant Natural := 4;
    Default_Memory : constant Positive := 1_048_576;
    --# How many counters the "memory" neuron has.

    Recipe_Error : exception;

    function Made (
            Name         : in String;
            Letter_Count : in Symbol
            ) return Neurons.Neuron'Class;
    --# A blank neuron of the kind this recipe name asks for, with the default settings.

    function Blank_Of_Kind (
            Kind : in String
            ) return Neurons.Neuron'Class;
    --# An empty neuron of the package that saved under this word, ready to Load.

    end Calipso.Neuron_Kinds;
