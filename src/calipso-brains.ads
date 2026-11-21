--  A brain made of neurons.
--
--  A brain is a list of neurons of any kinds, each with a weight. To give an
--  opinion it adds up the points of all its neurons and turns them into
--  probabilities. It fulfils the Oracle contract, so the collapse engine, the
--  repair and the exam work with it unchanged.
--
--  Its memory works as read - calculate - write:
--
--     read       look at the surroundings of a hidden letter
--     calculate  give an opinion; see how much the real letter surprises
--     write      every neuron corrects itself a little
--
--  So every test also counts as training (Study returns the test score).
--  The write step happens ONLY when the real letter is known. When the brain is
--  used to generate text, nothing is written.
--
--  A brain can be saved to a file (a ".brn" file) and loaded back, with its
--  alphabet and the number of lessons it has studied, to carry on later, to be
--  compared or to be copied to another computer. The same file is also Ada
--  source: it can be compiled into a program (see Thaw and Calipso.Records).

with Ada.Containers.Indefinite_Vectors;

with Calipso.Alphabets;
with Calipso.Blind_Spots;
with Calipso.Canvases;
with Calipso.Distributions;
with Calipso.Neurons;
with Calipso.Numbers;
with Calipso.Oracles;
with Calipso.Random_Sources;
with Calipso.Records;
with Calipso.Sources;
with Calipso.Texts;

package Calipso.Brains is

    Default_Learning_Rate : constant Long_Float := 0.1;
    --# How big each correction is. Small steps learn slowly; big steps overshoot.

    type Brain is new Oracles.Oracle with private;
    --# A newly declared brain has no neurons and only the unknown symbol.

    procedure Prepare (
            Self    : in out Brain;
            Letters : in     Alphabets.Alphabet
            );
    --# An empty brain over this alphabet: no neurons, no lessons.

    procedure Add_Neuron (
            Self   : in out Brain;
            Item   : in     Neurons.Neuron'Class;
            Weight : in     Long_Float := 1.0
            );

    procedure Add_Recipe (
            Self   : in out Brain;
            Recipe : in     String
            );
    --# A recipe is a list of neuron names joined by "+", for example "bias+position+decay".
    --# Raises Neuron_Kinds.Recipe_Error if a name is not in the catalogue.

    function Neuron_Count (
            Self : in Brain
            ) return Natural;

    function Recipe_Of (
            Self : in Brain
            ) return String;

    function Lessons_Studied (
            Self : in Brain
            ) return Natural;
    --# How many lessons it has studied in its whole life, across runs.

    function Letters_Of (
            Self : in Brain
            ) return Alphabets.Alphabet;

    function Neuron_Reach (
            Self  : in Brain;
            Index : in Positive
            ) return Natural
        with Pre => Index <= Neuron_Count (Self);

    function Neuron_Opinion (
            Self     : in Brain;
            Index    : in Positive;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution
        with Pre => Index <= Neuron_Count (Self) and then Position <= Canvases.Length (Board);
    --# What ONE neuron would say if it were alone. Used to measure how much the neurons agree.

    procedure Learn_Cell (
            Self     : in out Brain;
            Board    : in     Canvases.Canvas;
            Position : in     Positive;
            Actual   : in     Symbol;
            Result   : in out Blind_Spots.Exam_Result
            )
        with Pre => Neuron_Count (Self) > 0 and then Position <= Canvases.Length (Board);
    --# Read - calculate - write on one hidden letter. The test score goes into Result
    --# BEFORE anything is corrected, so the test is honest.

    procedure Study_Piece (
            Self   : in out Brain;
            Piece  : in     Texts.Symbol_Text;
            Dice   : in out Random_Sources.Generator;
            Result : in out Blind_Spots.Exam_Result
            )
        with Pre => Neuron_Count (Self) > 0;
    --# One lesson: hide a random amount of the piece, test and correct on every
    --# hidden letter, then let the neurons that memorize text read the piece.

    procedure Study (
            Self    : in out Brain;
            From    : in out Sources.Source'Class;
            Dice    : in out Random_Sources.Generator;
            Lessons : in     Natural;
            Result  :    out Blind_Spots.Exam_Result
            )
        with Pre => Neuron_Count (Self) > 0;
    --# Studies up to Lessons pieces from the source. Stops early if the source runs dry.
    --# Result is the score of the tests taken along the way.

    procedure Save (
            Self      : in Brain;
            File_Name : in String
            );
    --# Raises Records.Record_Error if the file cannot be written.

    procedure Load (
            Self      : in out Brain;
            File_Name : in     String
            );
    --# Raises Records.Record_Error if the file is missing or is not a saved brain.

    procedure Thaw (
            Self    : in out Brain;
            Words   : in     Records.Word_List;
            Figures : in     Records.Number_List
            );
    --# The same as Load, for a brain file that was compiled into the program:
    --# Words and Figures are the two constants (Words and Numbers) its package declares.
    --# Raises Records.Record_Error if they are not a saved brain.

    overriding function Alphabet_Size (
            Self : in Brain
            ) return Symbol;

    overriding function Reach (
            Self : in Brain
            ) return Natural;

    overriding function Opinion (
            Self     : in Brain;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution;

private

    package Neuron_Lists is new Ada.Containers.Indefinite_Vectors (
            Index_Type   => Positive,
            Element_Type => Neurons.Neuron'Class,
            "="          => Neurons.Same
            );

    type Brain is new Oracles.Oracle with record
        Alphabet      : Alphabets.Alphabet;
        Cells         : Neuron_Lists.Vector;
        Weights       : Numbers.Real_Row;
        Studied       : Natural := 0;
        Learning_Rate : Long_Float := Default_Learning_Rate;
        end record;

    end Calipso.Brains;
