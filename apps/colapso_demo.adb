--  Colapsar una plantilla.
--
--  Uso:
--     colapso_demo CORPUS "PLANTILLA" [SEMILLA]
--
--  Ejemplo:
--     colapso_demo data/muestra.txt "\nEl azúcar [40] y por eso debes lavarte los dientes.\n" 7

with Ada.Command_Line;
with Ada.Exceptions;

with Colapso.Alphabets;
with Colapso.Canvases;
with Colapso.Collapsing;
with Colapso.Console;
with Colapso.Counting_Oracles;
with Colapso.Random_Sources;
with Colapso.Repairing;
with Colapso.Templates;
with Colapso.Texts;

procedure Colapso_Demo is

    use Colapso;

    Default_Seed : constant Natural := 1;
    Trace_Every  : constant Positive := 8;
    --# Cada cuántas letras colapsadas se pinta el lienzo.

    procedure Show_Usage is
        begin
        Console.Put_Line ("Uso:");
        Console.Put_Line ("   colapso_demo CORPUS ""PLANTILLA"" [SEMILLA]");
        Console.Put_Line ("");
        Console.Put_Line ("En la plantilla:");
        Console.Put_Line ("   _      un hueco de una celda");
        Console.Put_Line ("   [25]   un hueco de 25 celdas");
        Console.Put_Line ("   [...]  un hueco del tamaño por defecto");
        Console.Put_Line ("   \n     un salto de línea (frontera de párrafo)");
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
            "Corpus: " & Console.Image (Natural (Corpus.Length)) & " letras, alfabeto de "
            & Console.Image (Integer (Alphabets.Size (Letters))) & " símbolos."
            );

        Board := Templates.Parsed (Template, Letters);
        Console.Put_Line ("Plantilla:");
        Show_Board (Board, Letters, False);

        Console.Put_Line ("Colapso:");
        Collapsing.Collapse_All (Board, Model, Dice, Observer => Show_Step'Access);
        Show_Board (Board, Letters, False);

        Before := Repairing.Tension (Board, Model, Options.Tolerance);
        Repairing.Relax (Board, Model, Dice, Outcome, Options);
        Console.Put_Line ("Tensión antes de reparar: " & Console.Image (Before, 3));
        Console.Put_Line (
            "Reparación: " & Console.Image (Outcome.Rounds) & " rondas, "
            & Console.Image (Outcome.Reopenings) & " reaperturas, "
            & Console.Image (Outcome.Widenings) & " ensanches."
            );
        Console.Put_Line ("Tensión final: " & Console.Image (Outcome.Final_Tension, 3));
        Console.Put_Line ("Resultado (entre corchetes, lo que escribió el modelo):");
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
            raise Bad_Argument with "la semilla debe ser un número entero mayor o igual que 0";
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
    end Colapso_Demo;
