--  A brain that learns.
--
--  Idea: every known neighbour VOTES. A vote is a row of points, for or
--  against each candidate letter. There is a different row of points for
--  each pair (distance to the hole, letter found there):
--
--     "I have a q right on your left"  ->  many points for u
--
--  To give an opinion, the votes of all known neighbours are added up (holes
--  do not vote) and the points are turned into probabilities.
--
--  At the start every point is 0: the brain knows nothing. It learns by
--  playing the blind-spot game: a letter is hidden, it gives its opinion, it
--  is shown the real letter, and each neighbour that voted corrects its points a little.

with Ada.Containers.Vectors;

with Calipso.Canvases;
with Calipso.Distributions;
with Calipso.Oracles;
with Calipso.Random_Sources;
with Calipso.Texts;

package Calipso.Voting_Oracles is

    Default_Reach : constant Positive := 12;
    --# Up to how many cells away a neighbour votes, on each side.

    type Lesson_Plan is record
        Lessons       : Natural := 4_000;
        --# How many pieces of text are studied.
        Piece_Length  : Positive := 64;
        Learning_Rate : Long_Float := 0.5;
        --# How much of the error is corrected on each letter: 0 = nothing, 1 = all at once.
        end record;

    Default_Plan : constant Lesson_Plan := (others => <>);

    Not_Prepared : exception;
    --# An opinion was asked of a brain on which Prepare was never called.

    type Voting_Oracle is new Oracles.Oracle with private;

    procedure Prepare (
            Self         : in out Voting_Oracle;
            Letter_Count : in     Symbol;
            Reach        : in     Positive := Default_Reach
            );
    --# Leaves the brain blank: all points at 0.

    procedure Learn_Cell (
            Self          : in out Voting_Oracle;
            Board         : in     Canvases.Canvas;
            Position      : in     Positive;
            Actual        : in     Symbol;
            Learning_Rate : in     Long_Float;
            Surprise      :    out Long_Float
            )
        with Pre => Position <= Canvases.Length (Board) and then Actual <= Alphabet_Size (Self);
    --# A minimal lesson: give an opinion on a hidden cell, look at the real letter and correct.
    --# Surprise is the surprise the real letter caused BEFORE correcting.

    procedure Train (
            Self           : in out Voting_Oracle;
            Text           : in     Texts.Symbol_Text;
            Dice           : in out Random_Sources.Generator;
            Final_Surprise :    out Long_Float;
            Plan           : in     Lesson_Plan := Default_Plan
            )
        with Pre => Natural (Text.Length) > Plan.Piece_Length;
    --# Training = playing the blind-spot game many times.
    --# Final_Surprise is the mean surprise over the last tenth of the lessons.

    overriding function Alphabet_Size (
            Self : in Voting_Oracle
            ) return Symbol;

    overriding function Reach (
            Self : in Voting_Oracle
            ) return Natural;

    overriding function Opinion (
            Self     : in Voting_Oracle;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution;

private

    package Real_Vectors is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Long_Float
            );

    type Voting_Oracle is new Oracles.Oracle with record
        Letter_Count : Symbol := 1;
        Vote_Reach   : Positive := Default_Reach;
        Bias         : Real_Vectors.Vector;
        --# Bias (candidate): starting points of each letter, without looking at anyone.
        Votes        : Real_Vectors.Vector;
        --# All the votes in one long row. See Slot_Of in the body.
        end record;

    end Calipso.Voting_Oracles;
