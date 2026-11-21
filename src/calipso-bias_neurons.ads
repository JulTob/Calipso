--  The neuron that looks at nothing.
--
--  It holds one number per letter: its starting points, whatever the
--  surroundings. It learns how frequent each letter is.

with Ada.Text_IO;

with Calipso.Canvases;
with Calipso.Distributions;
with Calipso.Neurons;
with Calipso.Numbers;

package Calipso.Bias_Neurons is

    type Bias_Neuron is new Neurons.Neuron with private;

    procedure Prepare (
            Self         : in out Bias_Neuron;
            Letter_Count : in     Symbol
            );

    overriding function Name (
            Self : in Bias_Neuron
            ) return String;

    overriding function Kind (
            Self : in Bias_Neuron
            ) return String;

    overriding function Reach (
            Self : in Bias_Neuron
            ) return Natural;

    overriding procedure Add_Scores (
            Self     : in     Bias_Neuron;
            Board    : in     Canvases.Canvas;
            Position : in     Positive;
            Strength : in     Long_Float;
            Scores   : in out Distributions.Score_Array
            );

    overriding procedure Learn_From_Cell (
            Self     : in out Bias_Neuron;
            Board    : in     Canvases.Canvas;
            Position : in     Positive;
            Errors   : in     Distributions.Score_Array;
            Step     : in     Long_Float
            );

    overriding procedure Save (
            Self : in Bias_Neuron;
            File : in Ada.Text_IO.File_Type
            );

    overriding procedure Load (
            Self : in out Bias_Neuron;
            File : in     Ada.Text_IO.File_Type
            );

private

    type Bias_Neuron is new Neurons.Neuron with record
        Letter_Count : Symbol := 1;
        Points       : Numbers.Real_Row;
        --# Points (candidate): the starting points of each letter.
        end record;

    end Calipso.Bias_Neurons;
