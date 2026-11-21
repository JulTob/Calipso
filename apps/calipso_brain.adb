--  Brains that are kept between runs.
--
--  Usage:
--     calipso_brain study BRAIN_FILE CORPUS [LESSONS] [RECIPE]
--     calipso_brain compare CORPUS BRAIN_FILE [BRAIN_FILE ...]
--
--  study   : loads the brain from BRAIN_FILE, or makes a new one from RECIPE if
--            the file does not exist. It studies LESSONS more lessons, takes the
--            exam, and saves the brain back. Run it again and it carries on.
--  compare : gives the same exam to several saved brains.
--
--  A recipe is a list of neuron names joined by "+":
--     bias  position  presence  harmonic  decay  counting  memory
--
--  It mirrors reference/brain.py: with the same arguments it writes the same.

with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;

with Calipso.Alphabets;
with Calipso.Blind_Spots;
with Calipso.Brains;
with Calipso.Console;
with Calipso.Memory_Sources;
with Calipso.Neuron_Kinds;
with Calipso.Random_Sources;
with Calipso.Records;
with Calipso.Texts;

procedure Calipso_Brain is

    use Calipso;

    Default_Lessons : constant Natural := 2_000;
    Default_Recipe  : constant String := "bias+position";
    Piece_Length    : constant Positive := 64;
    Exam_Pieces     : constant Positive := 40;
    Exam_Seed       : constant Natural := 505;
    Study_Seed      : constant Natural := 77;
    Hiding_Seed     : constant Natural := 1_077;

    type Rate_Case is record
        Rate    : Random_Sources.Unit_Fraction;
        Percent : Natural;
        end record;

    Rate_Cases : constant array (1 .. 3) of Rate_Case := (
        (Rate => 0.15, Percent => 15),
        (Rate => 0.50, Percent => 50),
        (Rate => 0.85, Percent => 85)
        );

    Bad_Argument : exception;

    function Percent_Image (
            Part  : in Natural;
            Whole : in Natural
            ) return String is
        Share : Long_Float;
        begin
        if Whole = 0 then
            return "  n/a";
            end if;
        Share := 100.0 * Long_Float (Part) / Long_Float (Whole);
        return Ada.Strings.Fixed.Tail (Console.Image (Share, 1), 5);
        end Percent_Image;

    procedure Show_Exam (
            Brain : in Brains.Brain;
            Exam  : in Texts.Symbol_Text
            ) is
        Dice     : Random_Sources.Generator;
        Result   : Blind_Spots.Exam_Result;
        Surprise : Long_Float;
        begin
        for Chosen of Rate_Cases loop
            Dice := Random_Sources.Seeded (Exam_Seed);
            --# Same seed for all: every brain gets the same pieces and the same holes.
            Blind_Spots.Examine (Brain, Exam, Dice, Exam_Pieces, Piece_Length, Chosen.Rate, Result);
            Surprise := Blind_Spots.Mean_Surprise (Result);
            Console.Put_Line (
                "  hidden " & Console.Image (Chosen.Percent) & " %: "
                & Percent_Image (Result.Hits, Result.Hidden) & " %   "
                & Console.Image (Surprise, 3) & " nats"
                );
            end loop;
        end Show_Exam;

    procedure Split (
            Corpus     : in     Texts.Symbol_Text;
            Study_Text :    out Texts.Symbol_Text;
            Exam_Text  :    out Texts.Symbol_Text
            ) is
        Length : constant Natural := Natural (Corpus.Length);
        Cut    : constant Natural := (Length * 9) / 10;
        begin
        Study_Text := Texts.Part (Corpus, 1, Cut);
        Exam_Text := Texts.Part (Corpus, Cut + 1, Length);
        end Split;
    --# The first 90 % to study from, the last 10 % to examine with.

    procedure Make_Or_Load (
            Brain       : in out Brains.Brain;
            Brain_Name  : in     String;
            Corpus_Name : in     String;
            Recipe      : in     String
            ) is
        Letters : Alphabets.Alphabet;
        begin
        if Ada.Directories.Exists (Brain_Name) then
            Brains.Load (Brain, Brain_Name);
            Console.Put_Line (
                "Brain: " & Brains.Recipe_Of (Brain) & " (loaded, "
                & Console.Image (Brains.Lessons_Studied (Brain)) & " lessons so far)"
                );
            return;
            end if;
        Texts.Learn_Alphabet (Corpus_Name, Letters);
        Brains.Prepare (Brain, Letters);
        Brains.Add_Recipe (Brain, Recipe);
        Console.Put_Line ("Brain: " & Brains.Recipe_Of (Brain) & " (new)");
        end Make_Or_Load;

    procedure Run_Study (
            Brain_Name  : in String;
            Corpus_Name : in String;
            Lessons     : in Natural;
            Recipe      : in String
            ) is
        Brain      : Brains.Brain;
        Corpus     : Texts.Symbol_Text;
        Study_Text : Texts.Symbol_Text;
        Exam_Text  : Texts.Symbol_Text;
        Source     : Memory_Sources.Memory_Source;
        Dice       : Random_Sources.Generator;
        Result     : Blind_Spots.Exam_Result;
        Surprise   : Long_Float;
        begin
        Make_Or_Load (Brain, Brain_Name, Corpus_Name, Recipe);
        Corpus := Texts.Read_Symbols (Corpus_Name, Brains.Letters_Of (Brain));
        --# The corpus is read with the brain's own alphabet, so a loaded brain keeps its letters.
        Split (Corpus, Study_Text, Exam_Text);
        if Natural (Exam_Text.Length) <= Piece_Length then
            Console.Put_Line ("Error: the corpus is too short for this experiment.");
            return;
            end if;
        Console.Put_Line (
            "Corpus: " & Console.Image (Natural (Corpus.Length)) & " letters. Studies from "
            & Console.Image (Natural (Study_Text.Length)) & ", examines with "
            & Console.Image (Natural (Exam_Text.Length)) & "."
            );
        Memory_Sources.Open (Source, Study_Text, Piece_Length, Study_Seed + Brains.Lessons_Studied (Brain));
        Dice := Random_Sources.Seeded (Hiding_Seed + Brains.Lessons_Studied (Brain));
        --# The seeds move with the lessons already studied: a second run sees new pieces.
        Brains.Study (Brain, Source, Dice, Lessons, Result);
        Surprise := Blind_Spots.Mean_Surprise (Result);
        Console.Put_Line (
            "Studied " & Console.Image (Lessons) & " lessons. While studying: right "
            & Percent_Image (Result.Hits, Result.Hidden) & " %, mean surprise "
            & Console.Image (Surprise, 3) & " nats (" & Console.Image (Result.Hidden) & " letters)"
            );
        Console.Put_Line ("Lessons so far: " & Console.Image (Brains.Lessons_Studied (Brain)));
        Console.Put_Line ("Exam (hidden letters right, mean surprise):");
        Show_Exam (Brain, Exam_Text);
        Brains.Save (Brain, Brain_Name);
        Console.Put_Line ("Saved to " & Brain_Name);
        end Run_Study;

    procedure Compare_One (
            Corpus_Name : in String;
            Brain_Name  : in String
            ) is
        Brain      : Brains.Brain;
        Corpus     : Texts.Symbol_Text;
        Study_Text : Texts.Symbol_Text;
        Exam_Text  : Texts.Symbol_Text;
        begin
        Brains.Load (Brain, Brain_Name);
        Corpus := Texts.Read_Symbols (Corpus_Name, Brains.Letters_Of (Brain));
        Split (Corpus, Study_Text, Exam_Text);
        if Natural (Exam_Text.Length) <= Piece_Length then
            Console.Put_Line ("Error: the corpus is too short for this experiment.");
            return;
            end if;
        Console.Put_Line (
            Brain_Name & ": " & Brains.Recipe_Of (Brain) & ", "
            & Console.Image (Brains.Lessons_Studied (Brain)) & " lessons"
            );
        Show_Exam (Brain, Exam_Text);
        end Compare_One;

    function Whole_Number (
            Word : in String
            ) return Natural is
        begin
        return Natural'Value (Word);
        exception
        when Constraint_Error =>
            raise Bad_Argument with "the number of lessons must be a whole number, 0 or greater";
        end Whole_Number;

    procedure Show_Usage is
        begin
        Console.Put_Line ("Usage:");
        Console.Put_Line ("   calipso_brain study BRAIN_FILE CORPUS [LESSONS] [RECIPE]");
        Console.Put_Line ("   calipso_brain compare CORPUS BRAIN_FILE [BRAIN_FILE ...]");
        end Show_Usage;

    procedure Study_Command is
        Count   : constant Natural := Ada.Command_Line.Argument_Count;
        Lessons : Natural := Default_Lessons;
        begin
        if Count >= 4 then
            Lessons := Whole_Number (Ada.Command_Line.Argument (4));
            end if;
        if Count >= 5 then
            Run_Study (Ada.Command_Line.Argument (2), Ada.Command_Line.Argument (3), Lessons, Ada.Command_Line.Argument (5));
        else
            Run_Study (Ada.Command_Line.Argument (2), Ada.Command_Line.Argument (3), Lessons, Default_Recipe);
            end if;
        end Study_Command;

    procedure Compare_Command is
        begin
        for Index in 3 .. Ada.Command_Line.Argument_Count loop
            Compare_One (Ada.Command_Line.Argument (2), Ada.Command_Line.Argument (Index));
            end loop;
        end Compare_Command;

    begin
    if Ada.Command_Line.Argument_Count >= 3 and then Ada.Command_Line.Argument (1) = "study" then
        Study_Command;
    elsif Ada.Command_Line.Argument_Count >= 3 and then Ada.Command_Line.Argument (1) = "compare" then
        Compare_Command;
    else
        Show_Usage;
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
        end if;
    exception
    when Problem : Texts.Reading_Error | Records.Record_Error | Neuron_Kinds.Recipe_Error | Bad_Argument =>
        Console.Put_Line ("Error: " & Ada.Exceptions.Exception_Message (Problem));
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
    end Calipso_Brain;
