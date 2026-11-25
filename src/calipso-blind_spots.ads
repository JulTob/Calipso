--  The blind-spot experiment.
--
--  Take real text, hide letters at random and ask the model to fill them
--  in. Since we know the answer, we can count hits.
--
--  With the counting brain this is an EXAM. With a brain that learns, this
--  same game is the TRAINING: hide, bet, uncover and correct.

with Calipso.Canvases;
with Calipso.Oracles;
with Calipso.Random_Sources;
with Calipso.Texts;

package Calipso.Blind_Spots is

    type Score is record
        Hidden    : Natural := 0;
        Recovered : Natural := 0;
        end record;

    procedure Hide_At_Random (
            Board : in out Canvases.Canvas;
            Rate  : in     Random_Sources.Unit_Fraction;
            Dice  : in out Random_Sources.Generator
            );
    --# Each given letter is hidden with probability Rate.

    function Scored (
            Filled   : in Canvases.Canvas;
            Original : in Canvases.Canvas
            ) return Score
        with Pre => Canvases.Length (Filled) = Canvases.Length (Original);
    --# Compares the filled canvas with the original, cell by cell.

    type Exam_Result is record
        Hidden       : Natural := 0;
        Hits         : Natural := 0;
        Surprise_Sum : Long_Float := 0.0;
        end record;

    function "+" (
            Left  : in Exam_Result;
            Right : in Exam_Result
            ) return Exam_Result;
    --# The score of two exams taken one after the other.

    function Mean_Surprise (
            Result : in Exam_Result
            ) return Long_Float;

    procedure Examine (
            Model        : in     Oracles.Oracle'Class;
            Text         : in     Texts.Symbol_Text;
            Dice         : in out Random_Sources.Generator;
            Pieces       : in     Natural;
            Piece_Length : in     Positive;
            Rate         : in     Random_Sources.Unit_Fraction;
            Result       :    out Exam_Result
            )
        with Pre => Natural (Text.Length) > Piece_Length;
    --# The same exam for any brain: hide letters at random in pieces of
    --# text and ask about each hidden letter, WITHOUT filling in the others.
    --# It measures two things: how many it gets right and how much the real letter surprises it.

    end Calipso.Blind_Spots;
