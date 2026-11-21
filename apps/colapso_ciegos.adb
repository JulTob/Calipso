--  El experimento de los puntos ciegos, en Ada.
--
--  Aprende del primer 90 % del corpus y examina con el último 10 %
--  (texto que el modelo no ha visto nunca). Tapa letras al azar y cuenta
--  cuántas recupera, con tres órdenes de visita distintos.
--
--  Es el espejo del experimento E2 de referencia/experimentos.py:
--  con el mismo corpus y los mismos ensayos debe dar las mismas cifras.
--
--  Uso:
--     colapso_ciegos CORPUS [ENSAYOS]

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Strings.Fixed;

with Colapso.Alphabets;
with Colapso.Blind_Spots;
with Colapso.Canvases;
with Colapso.Collapsing;
with Colapso.Console;
with Colapso.Counting_Oracles;
with Colapso.Random_Sources;
with Colapso.Templates;
with Colapso.Texts;

procedure Colapso_Ciegos is

    use Colapso;

    Default_Trials : constant Positive := 60;
    Piece_Length   : constant Positive := 300;
    Base_Seed      : constant Natural := 202;

    type Rate_Case is record
        Rate    : Random_Sources.Unit_Fraction;
        Percent : Natural;
        end record;

    Rate_Cases : constant array (1 .. 4) of Rate_Case := (
        (Rate => 0.15, Percent => 15),
        (Rate => 0.30, Percent => 30),
        (Rate => 0.50, Percent => 50),
        (Rate => 0.70, Percent => 70)
        );

    function Order_Name (
            Order : in Collapsing.Visiting_Order
            ) return String is
        begin
        case Order is
            when Collapsing.Most_Certain_First =>
                return "menos dudas primero";
            when Collapsing.Left_To_Right =>
                return "izquierda a derecha";
            when Collapsing.At_Random =>
                return "orden al azar      ";
            end case;
        end Order_Name;

    function Percent_Image (
            Part  : in Natural;
            Whole : in Natural
            ) return String is
        Share : Long_Float;
        begin
        if Whole = 0 then
            return "  n/d";
            end if;
        Share := 100.0 * Long_Float (Part) / Long_Float (Whole);
        return Ada.Strings.Fixed.Tail (Console.Image (Share, 1), 5);
        end Percent_Image;

    procedure Measure (
            Model     : in     Counting_Oracles.Counting_Oracle;
            Exam      : in     Texts.Symbol_Text;
            Rate      : in     Random_Sources.Unit_Fraction;
            Order     : in     Collapsing.Visiting_Order;
            Trials    : in     Positive;
            Hidden    :    out Natural;
            Recovered :    out Natural
            ) is
        Room   : constant Positive := Natural (Exam.Length) - Piece_Length;
        Dice   : Random_Sources.Generator;
        Start  : Natural;
        Result : Blind_Spots.Score;
        begin
        Hidden := 0;
        Recovered := 0;
        for Trial in 0 .. Trials - 1 loop
            Dice := Random_Sources.Seeded (Base_Seed + Trial);
            --# Misma semilla por ensayo: todos los órdenes reciben el mismo trozo y los mismos huecos.
            Random_Sources.Draw_Index (Dice, Room, Start);
            declare
                Original : constant Canvases.Canvas := Templates.From_Text (Exam, Start + 1, Piece_Length);
                Board    : Canvases.Canvas := Original;
                begin
                Blind_Spots.Hide_At_Random (Board, Rate, Dice);
                Collapsing.Collapse_All (Board, Model, Dice, Order, Collapsing.Always_Most_Likely);
                Result := Blind_Spots.Scored (Board, Original);
                end;
            Hidden := Hidden + Result.Hidden;
            Recovered := Recovered + Result.Recovered;
            end loop;
        end Measure;

    procedure Run (
            Corpus_Name : in String;
            Trials      : in Positive
            ) is
        Letters   : Alphabets.Alphabet;
        Corpus    : Texts.Symbol_Text;
        Lessons   : Texts.Symbol_Text;
        Exam      : Texts.Symbol_Text;
        Model     : Counting_Oracles.Counting_Oracle;
        Cut       : Natural;
        Hidden    : Natural;
        Recovered : Natural;
        begin
        Texts.Learn_Alphabet (Corpus_Name, Letters);
        Corpus := Texts.Read_Symbols (Corpus_Name, Letters);
        Cut := (Natural (Corpus.Length) * 9) / 10;
        Lessons := Texts.Part (Corpus, 1, Cut);
        Exam := Texts.Part (Corpus, Cut + 1, Natural (Corpus.Length));
        if Natural (Exam.Length) <= Piece_Length then
            Console.Put_Line ("Error: el corpus es demasiado corto para este experimento.");
            return;
            end if;
        Counting_Oracles.Train (Model, Lessons, Alphabets.Size (Letters));
        Console.Put_Line (
            "Corpus: " & Console.Image (Natural (Corpus.Length)) & " letras. Aprende de "
            & Console.Image (Natural (Lessons.Length)) & ", examina con "
            & Console.Image (Natural (Exam.Length)) & "."
            );
        Console.Put_Line ("Puntos ciegos al azar: % de letras tapadas que se recuperan");
        for Chosen of Rate_Cases loop
            for Order in Collapsing.Visiting_Order loop
                Measure (Model, Exam, Chosen.Rate, Order, Trials, Hidden, Recovered);
                Console.Put_Line (
                    "  tapado " & Console.Image (Chosen.Percent) & " %  " & Order_Name (Order) & ": "
                    & Percent_Image (Recovered, Hidden) & " %   (" & Console.Image (Hidden) & " letras)"
                    );
                end loop;
            end loop;
        end Run;

    Bad_Argument : exception;

    function Trials_Argument return Positive is
        begin
        if Ada.Command_Line.Argument_Count < 2 then
            return Default_Trials;
            end if;
        return Positive'Value (Ada.Command_Line.Argument (2));
        exception
        when Constraint_Error =>
            raise Bad_Argument with "el número de ensayos debe ser un entero mayor que 0";
        end Trials_Argument;

    begin
    if Ada.Command_Line.Argument_Count < 1 then
        Console.Put_Line ("Uso:");
        Console.Put_Line ("   colapso_ciegos CORPUS [ENSAYOS]");
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
        return;
        end if;
    Run (Ada.Command_Line.Argument (1), Trials_Argument);
    exception
    when Problem : Texts.Reading_Error | Bad_Argument =>
        Console.Put_Line ("Error: " & Ada.Exceptions.Exception_Message (Problem));
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
    end Colapso_Ciegos;
