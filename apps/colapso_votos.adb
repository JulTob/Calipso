--  Entrenar un cerebro con puntos ciegos, en Ada.
--
--  Aprende del primer 90 % del corpus y examina con el último 10 %.
--  Compara tres cerebros con el mismo examen:
--
--     conteo              el de la etapa 1, que solo cuenta
--     votos sin entrenar  el que aprende, antes de aprender nada
--     votos entrenado     el mismo, después de jugar a los puntos ciegos
--
--  Es el espejo de referencia/votos.py: con el mismo corpus y las mismas
--  lecciones debe escribir lo mismo.
--
--  Uso:
--     colapso_votos CORPUS [LECCIONES]

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Strings.Fixed;

with Colapso.Alphabets;
with Colapso.Blind_Spots;
with Colapso.Console;
with Colapso.Counting_Oracles;
with Colapso.Oracles;
with Colapso.Random_Sources;
with Colapso.Texts;
with Colapso.Voting_Oracles;

procedure Colapso_Votos is

    use Colapso;

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
        --# Misma semilla para todos: cada cerebro recibe los mismos trozos y los mismos huecos.
        Result   : Blind_Spots.Exam_Result;
        Share    : Long_Float;
        Surprise : Long_Float;
        begin
        Blind_Spots.Examine (Model, Exam, Dice, Exam_Pieces, Exam_Piece_Length, Rate, Result);
        Share := 100.0 * Long_Float (Result.Hits) / Long_Float (Result.Hidden);
        Surprise := Blind_Spots.Mean_Surprise (Result);
        Console.Put_Line (
            "  tapado " & Console.Image (Percent) & " %  " & Name & ": "
            & Ada.Strings.Fixed.Tail (Console.Image (Share, 1), 5) & " %   "
            & Console.Image (Surprise, 3) & " nats   (" & Console.Image (Result.Hidden) & " letras)"
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
            Console.Put_Line ("Error: el corpus es demasiado corto para este experimento.");
            return;
            end if;
        Console.Put_Line (
            "Corpus: " & Console.Image (Natural (Corpus.Length)) & " letras. Aprende de "
            & Console.Image (Natural (Study.Length)) & ", examina con "
            & Console.Image (Natural (Exam.Length)) & "."
            );

        Counting_Oracles.Train (Counting, Study, Alphabets.Size (Letters));
        Voting_Oracles.Prepare (Untrained, Alphabets.Size (Letters));
        Voting_Oracles.Prepare (Trained, Alphabets.Size (Letters));
        Plan.Lessons := Lessons;
        Console.Put_Line (
            "Entrenando votos: " & Console.Image (Plan.Lessons) & " lecciones, alcance "
            & Console.Image (Voting_Oracles.Reach (Trained)) & "."
            );
        Voting_Oracles.Train (Trained, Study, Dice, Final_Surprise, Plan);
        Console.Put_Line (
            "Sorpresa media al final del entrenamiento: " & Console.Image (Final_Surprise, 3) & " nats"
            );

        Console.Put_Line ("Examen de puntos ciegos (acierto y sorpresa media por letra tapada):");
        for Chosen of Rate_Cases loop
            Show_Exam ("conteo            ", Counting, Exam, Chosen.Rate, Chosen.Percent);
            Show_Exam ("votos sin entrenar", Untrained, Exam, Chosen.Rate, Chosen.Percent);
            Show_Exam ("votos entrenado   ", Trained, Exam, Chosen.Rate, Chosen.Percent);
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
            raise Bad_Argument with "el número de lecciones debe ser un entero mayor o igual que 0";
        end Lessons_Argument;

    begin
    if Ada.Command_Line.Argument_Count < 1 then
        Console.Put_Line ("Uso:");
        Console.Put_Line ("   colapso_votos CORPUS [LECCIONES]");
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
        return;
        end if;
    Run (Ada.Command_Line.Argument (1), Lessons_Argument);
    exception
    when Problem : Texts.Reading_Error | Bad_Argument =>
        Console.Put_Line ("Error: " & Ada.Exceptions.Exception_Message (Problem));
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
    end Colapso_Votos;
