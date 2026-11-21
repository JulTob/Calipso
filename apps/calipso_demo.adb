--  Collapse a template.
--
--  Usage:
--     calipso_demo CORPUS "TEMPLATE" [SEED]
--
--  Example:
--     calipso_demo data/sample_es.txt "\nEl azúcar [40] y por eso debes lavarte los dientes.\n" 7

with Ada.Command_Line;
with Ada.Exceptions;

with Calipso.Alphabets;
with Calipso.Canvases;
with Calipso.Collapsing;
with Calipso.Console;
with Calipso.Counting_Oracles;
with Calipso.Random_Sources;
with Calipso.Repairing;
with Calipso.Templates;
with Calipso.Texts;

procedure Calipso_Demo is

    use Calipso;

    Default_Seed : constant Natural := 1;
    Trace_Every  : constant Positive := 8;
    --# How many collapsed letters between two drawings of the canvas.

    procedure Show_Usage is
        begin
        Console.Put_Line ("Usage:");
        Console.Put_Line ("   calipso_demo CORPUS ""TEMPLATE"" [SEED]");
        Console.Put_Line ("");
        Console.Put_Line ("In the template:");
        Console.Put_Line ("   _      a hole of one cell");
        Console.Put_Line ("   [25]   a hole of 25 cells");
        Console.Put_Line ("   [...]  a hole of the default size");
        Console.Put_Line ("   \n     a line break (paragraph boundary)");
        end Show_Usage;

    procedure Show_Board (
            Board        : in Canvases.Canvas;
            Letters      : in Alphabets.Alphabet;
            Mark_Guesses : in Boolean
            ) is
        Plain : constant Wide_Wide_String := Templates.Rendered (Board, Letters, Mark_Guesses);
        begin
        Console.Put_Wide_Line ("  " & Console.Visible (Plain));
        end Show_Board;

    procedure Run (
            Corpus_Name : in String;
            Template    : in Wide_Wide_String;
            Seed        : in Natural
            ) is
        Letters : Alphabets.Alphabet;
        Corpus  : Texts.Symbol_Text;
        Model   : Counting_Oracles.Counting_Oracle;
        Board   : Canvases.Canvas;
        Dice    : Random_Sources.Generator := Random_Sources.Seeded (Seed);
        Options : constant Repairing.Settings := Repairing.Default_Settings;
        Outcome : Repairing.Report;
        Before  : Long_Float;
        Steps   : Natural := 0;

        procedure Show_Step (
                Current  : in Canvases.Canvas;
                Position : in Positive
                ) is
            pragma Unreferenced (Position);
            begin
            Steps := Steps + 1;
            if Steps mod Trace_Every = 0 then
                Show_Board (Current, Letters, False);
                end if;
            end Show_Step;

        begin
        Texts.Learn_Alphabet (Corpus_Name, Letters);
        Corpus := Texts.Read_Symbols (Corpus_Name, Letters);
        Counting_Oracles.Train (Model, Corpus, Alphabets.Size (Letters));
        Console.Put_Line (
            "Corpus: " & Console.Image (Natural (Corpus.Length)) & " letters, alphabet of "
            & Console.Image (Integer (Alphabets.Size (Letters))) & " symbols."
            );

        Board := Templates.Parsed (Template, Letters);
        Console.Put_Line ("Template:");
        Show_Board (Board, Letters, False);

        Console.Put_Line ("Collapse:");
        Collapsing.Collapse_All (Board, Model, Dice, Observer => Show_Step'Access);
        Show_Board (Board, Letters, False);

        Before := Repairing.Tension (Board, Model, Options.Tolerance);
        Repairing.Relax (Board, Model, Dice, Outcome, Options);
        Console.Put_Line ("Tension before repair: " & Console.Image (Before, 3));
        Console.Put_Line (
            "Repair: " & Console.Image (Outcome.Rounds) & " rounds, "
            & Console.Image (Outcome.Reopenings) & " reopenings, "
            & Console.Image (Outcome.Widenings) & " widenings."
            );
        Console.Put_Line ("Final tension: " & Console.Image (Outcome.Final_Tension, 3));
        Console.Put_Line ("Result (in brackets, what the model wrote):");
        Show_Board (Board, Letters, True);
        end Run;

    Bad_Argument : exception;

    function Seed_Argument return Natural is
        begin
        if Ada.Command_Line.Argument_Count < 3 then
            return Default_Seed;
            end if;
        return Natural'Value (Ada.Command_Line.Argument (3));
        exception
        when Constraint_Error =>
            raise Bad_Argument with "the seed must be a whole number, 0 or greater";
        end Seed_Argument;

    begin
    if Ada.Command_Line.Argument_Count < 2 then
        Show_Usage;
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
        return;
        end if;
    Run (
        Corpus_Name => Ada.Command_Line.Argument (1),
        Template    => Console.From_UTF_8 (Ada.Command_Line.Argument (2)),
        Seed        => Seed_Argument
        );
    exception
    when Problem : Texts.Reading_Error | Bad_Argument =>
        Console.Put_Line ("Error: " & Ada.Exceptions.Exception_Message (Problem));
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
    end Calipso_Demo;
