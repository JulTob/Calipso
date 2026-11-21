--  Train a brain with blind spots, in Ada.
--
--  Learns from the first 90 % of the corpus and examines with the last 10 %.
--  Compares three brains with the same exam:
--
--     counting         the stage 1 brain, which only counts
--     votes untrained  the brain that learns, before learning anything
--     votes trained    the same brain, after playing the blind-spot game
--
--  It mirrors reference/train.py: with the same corpus and the same
--  lessons it must write the same output.
--
--  Usage:
--     calipso_train CORPUS [LESSONS]

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Strings.Fixed;

with Calipso.Alphabets;
with Calipso.Blind_Spots;
with Calipso.Console;
with Calipso.Counting_Oracles;
with Calipso.Oracles;
with Calipso.Random_Sources;
with Calipso.Texts;
with Calipso.Voting_Oracles;

procedure Calipso_Train is

    use Calipso;

    Exam_Pieces       : constant Positive := 40;
    Exam_Piece_Length : constant Positive := 64;
    Exam_Seed         : constant Natural := 505;
    Training_Seed     : constant Natural := 77;

    type Rate_Case is record
        Rate    : Random_Sources.Unit_Fraction;
        Percent : Natural;
        end record;

    Rate_Cases : constant array (1 .. 3) of Rate_Case := (
        (Rate => 0.15, Percent => 15),
        (Rate => 0.50, Percent => 50),
        (Rate => 0.85, Percent => 85)
        );

    procedure Show_Exam (
            Name    : in String;
            Model   : in Oracles.Oracle'Class;
            Exam    : in Texts.Symbol_Text;
            Rate    : in Random_Sources.Unit_Fraction;
            Percent : in Natural
            ) is
        Dice     : Random_Sources.Generator := Random_Sources.Seeded (Exam_Seed);
        --# Same seed for all: every brain gets the same pieces and the same holes.
        Result   : Blind_Spots.Exam_Result;
        Share    : Long_Float;
        Surprise : Long_Float;
        begin
        Blind_Spots.Examine (Model, Exam, Dice, Exam_Pieces, Exam_Piece_Length, Rate, Result);
        Share := 100.0 * Long_Float (Result.Hits) / Long_Float (Result.Hidden);
        Surprise := Blind_Spots.Mean_Surprise (Result);
        Console.Put_Line (
            "  hidden " & Console.Image (Percent) & " %  " & Name & ": "
            & Ada.Strings.Fixed.Tail (Console.Image (Share, 1), 5) & " %   "
            & Console.Image (Surprise, 3) & " nats   (" & Console.Image (Result.Hidden) & " letters)"
            );
        end Show_Exam;

    procedure Run (
            Corpus_Name : in String;
            Lessons     : in Natural
            ) is
        Letters        : Alphabets.Alphabet;
        Corpus         : Texts.Symbol_Text;
        Study          : Texts.Symbol_Text;
        Exam           : Texts.Symbol_Text;
        Counting       : Counting_Oracles.Counting_Oracle;
        Untrained      : Voting_Oracles.Voting_Oracle;
        Trained        : Voting_Oracles.Voting_Oracle;
        Plan           : Voting_Oracles.Lesson_Plan := Voting_Oracles.Default_Plan;
        Dice           : Random_Sources.Generator := Random_Sources.Seeded (Training_Seed);
        Cut            : Natural;
        Final_Surprise : Long_Float;
        begin
        Texts.Learn_Alphabet (Corpus_Name, Letters);
        Corpus := Texts.Read_Symbols (Corpus_Name, Letters);
        Cut := (Natural (Corpus.Length) * 9) / 10;
        Study := Texts.Part (Corpus, 1, Cut);
        Exam := Texts.Part (Corpus, Cut + 1, Natural (Corpus.Length));
        if Natural (Exam.Length) <= Exam_Piece_Length then
            Console.Put_Line ("Error: the corpus is too short for this experiment.");
            return;
            end if;
        Console.Put_Line (
            "Corpus: " & Console.Image (Natural (Corpus.Length)) & " letters. Learns from "
            & Console.Image (Natural (Study.Length)) & ", examines with "
            & Console.Image (Natural (Exam.Length)) & "."
            );

        Counting_Oracles.Train (Counting, Study, Alphabets.Size (Letters));
        Voting_Oracles.Prepare (Untrained, Alphabets.Size (Letters));
        Voting_Oracles.Prepare (Trained, Alphabets.Size (Letters));
        Plan.Lessons := Lessons;
        Console.Put_Line (
            "Training votes: " & Console.Image (Plan.Lessons) & " lessons, reach "
            & Console.Image (Voting_Oracles.Reach (Trained)) & "."
            );
        Voting_Oracles.Train (Trained, Study, Dice, Final_Surprise, Plan);
        Console.Put_Line (
            "Mean surprise at the end of training: " & Console.Image (Final_Surprise, 3) & " nats"
            );

        Console.Put_Line ("Blind-spot exam (hits and mean surprise per hidden letter):");
        for Chosen of Rate_Cases loop
            Show_Exam ("counting       ", Counting, Exam, Chosen.Rate, Chosen.Percent);
            Show_Exam ("votes untrained", Untrained, Exam, Chosen.Rate, Chosen.Percent);
            Show_Exam ("votes trained  ", Trained, Exam, Chosen.Rate, Chosen.Percent);
            end loop;
        end Run;

    Bad_Argument : exception;

    function Lessons_Argument return Natural is
        begin
        if Ada.Command_Line.Argument_Count < 2 then
            return Voting_Oracles.Default_Plan.Lessons;
            end if;
        return Natural'Value (Ada.Command_Line.Argument (2));
        exception
        when Constraint_Error =>
            raise Bad_Argument with "the number of lessons must be a whole number, 0 or greater";
        end Lessons_Argument;

    begin
    if Ada.Command_Line.Argument_Count < 1 then
        Console.Put_Line ("Usage:");
        Console.Put_Line ("   calipso_train CORPUS [LESSONS]");
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
        return;
        end if;
    Run (Ada.Command_Line.Argument (1), Lessons_Argument);
    exception
    when Problem : Texts.Reading_Error | Bad_Argument =>
        Console.Put_Line ("Error: " & Ada.Exceptions.Exception_Message (Problem));
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
    end Calipso_Train;
