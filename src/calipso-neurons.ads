--  The contract of any neuron.
--
--  A neuron is one way of looking at the surroundings of a cell. It does not
--  answer with a letter: it gives POINTS for or against each candidate letter.
--  Points simply add up, so neurons of different kinds can sit in one brain:
--
--     points of the brain = sum over its neurons of (weight x points of the neuron)
--
--  A neuron can learn in two ways, and each kind uses the one that suits it:
--
--     Learn_From_Cell : it is told how wrong the brain was on one hidden letter
--                       ("errors") and corrects its own numbers.
--     Learn_From_Text : it is shown a piece of real text and remembers it.


with Calipso.Canvases;
with Calipso.Distributions;
with Calipso.Records;
with Calipso.Texts;

package Calipso.Neurons is

    type Neuron is interface;

    function Name (
            Self : in Neuron
            ) return String is abstract;
    --# The name used in recipes: "bias", "position", "harmonic"...

    function Kind (
            Self : in Neuron
            ) return String is abstract;
    --# The word written in a saved brain to say which module must read it back.

    function Reach (
            Self : in Neuron
            ) return Natural is abstract;

    procedure Add_Scores (
            Self     : in     Neuron;
            Board    : in     Canvases.Canvas;
            Position : in     Positive;
            Strength : in     Long_Float;
            Scores   : in out Distributions.Score_Array
            ) is abstract;
    --# Adds Strength times its own points to Scores.

    procedure Learn_From_Cell (
            Self     : in out Neuron;
            Board    : in     Canvases.Canvas;
            Position : in     Positive;
            Errors   : in     Distributions.Score_Array;
            Step     : in     Long_Float
            ) is null;
    --# Errors (candidate) = what was bet on that letter, minus 1 for the real letter.
    --# Each of the neuron's numbers that took part moves against the error, by Step.
    --# A neuron that does not learn this way simply does nothing.

    procedure Learn_From_Text (
            Self  : in out Neuron;
            Piece : in     Texts.Symbol_Text
            ) is null;

    procedure Save (
            Self : in     Neuron;
            Tape : in out Records.Tape
            ) is abstract;

    procedure Load (
            Self : in out Neuron;
            Tape : in out Records.Tape
            ) is abstract;

    function Is_Voter (
            Board    : in Canvases.Canvas;
            Position : in Positive;
            Offset   : in Integer
            ) return Boolean;
    --# Is there a neighbour with a letter at that distance? (A cell never votes for itself.)

    function With_Sizes (
            Word         : in String;
            First        : in Natural;
            Usual_First  : in Natural;
            Second       : in Natural;
            Usual_Second : in Natural
            ) return String;
    --# The name of a neuron as a recipe writes it: the word alone when its
    --# sizes are the usual ones, and "word:first" or "word:first:second" when not.

    function Same (
            Left  : in Neuron'Class;
            Right : in Neuron'Class
            ) return Boolean;
    --# Needed by the list of neurons that a brain keeps.

    end Calipso.Neurons;
