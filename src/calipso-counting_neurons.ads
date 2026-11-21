--  The counting brain, as one neuron.
--
--  It wraps a counting oracle so that it can sit in a brain next to neurons
--  that learn. Its points for a letter are the logarithm of the probability the
--  count table gives it: that way, alone in a brain, it says exactly what the
--  counting oracle says; next to other neurons, they correct what it gets wrong.
--
--  It learns from text (it counts fragments), not from errors.


with Calipso.Canvases;
with Calipso.Counting_Oracles;
with Calipso.Distributions;
with Calipso.Neurons;
with Calipso.Records;
with Calipso.Texts;

package Calipso.Counting_Neurons is

    type Counting_Neuron is new Neurons.Neuron with private;

    procedure Prepare (
            Self         : in out Counting_Neuron;
            Letter_Count : in     Symbol;
            Longest      : in     Positive := Counting_Oracles.Default_Longest;
            Capacity     : in     Natural := 0
            );

    overriding function Name (
            Self : in Counting_Neuron
            ) return String;
    --# "counting" with exact memory, "memory" with bounded memory.

    overriding function Kind (
            Self : in Counting_Neuron
            ) return String;

    overriding function Reach (
            Self : in Counting_Neuron
            ) return Natural;

    overriding procedure Add_Scores (
            Self     : in     Counting_Neuron;
            Board    : in     Canvases.Canvas;
            Position : in     Positive;
            Strength : in     Long_Float;
            Scores   : in out Distributions.Score_Array
            );

    overriding procedure Learn_From_Text (
            Self  : in out Counting_Neuron;
            Piece : in     Texts.Symbol_Text
            );

    overriding procedure Save (
            Self : in     Counting_Neuron;
            Tape : in out Records.Tape
            );

    overriding procedure Load (
            Self : in out Counting_Neuron;
            Tape : in out Records.Tape
            );

private

    type Counting_Neuron is new Neurons.Neuron with record
        Oracle : Counting_Oracles.Counting_Oracle;
        end record;

    end Calipso.Counting_Neurons;
