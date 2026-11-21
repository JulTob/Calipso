--  Pruebas de Colapso.
--
--  Dos clases de comprobación:
--
--     Check        : debe cumplirse siempre. Si falla, el programa termina con error.
--     Check_Mirror : compara con lo que dio la referencia en Python con la misma
--                    semilla. Si no coincide solo avisa, porque una diferencia de
--                    redondeo entre máquinas puede cambiar un sorteo sin que haya fallo.
--
--  Los valores esperados salen de referencia/pruebas.py (mismo corpus, mismos pasos).

with Ada.Command_Line;
with Ada.Exceptions;

with Colapso.Alphabets;
with Colapso.Blind_Spots;
with Colapso.Canvases;
with Colapso.Collapsing;
with Colapso.Console;
with Colapso.Counting_Oracles;
with Colapso.Distributions;
with Colapso.Fragment_Counts;
with Colapso.Random_Sources;
with Colapso.Repairing;
with Colapso.Templates;
with Colapso.Texts;
with Colapso.Voting_Oracles;

procedure Colapso_Tests is

    use Colapso;
    use type Canvases.Cell_State;
    use type Distributions.Distribution;

    Corpus_Text : constant Wide_Wide_String :=
        "la casa de la costa es la casa de la rosa. la rosa de la casa es la cosa de la costa. "
        & "el oso de la rosa es el oso de la casa. la casa del oso es la costa.";

    Test_Longest : constant Positive := 5;
    Tolerance    : constant Long_Float := 1.0E-9;

    Letters : Alphabets.Alphabet;
    Corpus  : Texts.Symbol_Text;
    Model   : Counting_Oracles.Counting_Oracle;

    Failures : Natural := 0;
    Warnings : Natural := 0;

    procedure Check (
            Name      : in String;
            Condition : in Boolean
            ) is
        begin
        if Condition then
            Console.Put_Line ("  ok     " & Name);
        else
            Console.Put_Line ("  FALLO  " & Name);
            Failures := Failures + 1;
            end if;
        end Check;

    procedure Check_Close (
            Name     : in String;
            Actual   : in Long_Float;
            Expected : in Long_Float
            ) is
        Difference : constant Long_Float := abs (Actual - Expected);
        begin
        Check (Name, Difference <= Tolerance);
        if Difference > Tolerance then
            Console.Put_Line ("         obtenido " & Console.Image (Actual, 12));
            Console.Put_Line ("         esperado " & Console.Image (Expected, 12));
            end if;
        end Check_Close;

    procedure Check_Mirror (
            Name     : in String;
            Actual   : in Wide_Wide_String;
            Expected : in Wide_Wide_String
            ) is
        begin
        if Actual = Expected then
            Console.Put_Line ("  ok     " & Name);
        else
            Console.Put_Line ("  AVISO  " & Name & " (no coincide con la referencia)");
            Console.Put_Wide_Line ("         obtenido " & Actual);
            Console.Put_Wide_Line ("         esperado " & Expected);
            Warnings := Warnings + 1;
            end if;
        end Check_Mirror;

    procedure Run_Group (
            Title : in String;
            Group : not null access procedure
            ) is
        begin
        Console.Put_Line (Title);
        Group.all;
        exception
        when Problem : others =>
            Console.Put_Line ("  FALLO  excepción: " & Ada.Exceptions.Exception_Information (Problem));
            Failures := Failures + 1;
        end Run_Group;

    function Symbol_For (
            Char : in Wide_Wide_Character
            ) return Symbol is
        begin
        return Alphabets.Symbol_Of (Letters, Char);
        end Symbol_For;

    function Piece_Of (
            Plain : in Wide_Wide_String
            ) return Fragment_Counts.Fragment is
        Encoded_Plain : constant Texts.Symbol_Text := Texts.Encoded (Plain, Letters);
        begin
        return Fragment_Counts.Slice (Encoded_Plain, 1, Plain'Length);
        end Piece_Of;

    function Seen (
            Plain : in Wide_Wide_String
            ) return Natural is
        Table : Fragment_Counts.Count_Table;
        begin
        Fragment_Counts.Learn (Table, Corpus, Test_Longest);
        return Fragment_Counts.Count_Of (Table, Piece_Of (Plain));
        end Seen;

    function Givens_Kept (
            Board    : in Canvases.Canvas;
            Template : in Wide_Wide_String
            ) return Boolean is
        Original : constant Canvases.Canvas := Templates.Parsed (Template, Letters);
        Cursor   : Natural := 0;
        begin
        for Position in 1 .. Canvases.Length (Original) loop
            if Canvases.State_At (Original, Position) = Canvases.Given then
                loop
                    Cursor := Cursor + 1;
                    if Cursor > Canvases.Length (Board) then
                        return False;
                        end if;
                    exit when Canvases.State_At (Board, Cursor) = Canvases.Given;
                    end loop;
                if Canvases.Symbol_At (Board, Cursor) /= Canvases.Symbol_At (Original, Position) then
                    return False;
                    end if;
                end if;
            end loop;
        return True;
        end Givens_Kept;
    --# ¿Siguen en el lienzo, en el mismo orden, todas las letras dadas de la plantilla?

    procedure Prepare is
        begin
        for Char of Corpus_Text loop
            Alphabets.Include (Letters, Char);
            end loop;
        Corpus := Texts.Encoded (Corpus_Text, Letters);
        Counting_Oracles.Train (Model, Corpus, Alphabets.Size (Letters), Test_Longest);
        end Prepare;

    procedure Test_Random_Sources is
        Dice  : Random_Sources.Generator := Random_Sources.Seeded (42);
        Unit  : Random_Sources.Unit_Fraction;
        Index : Natural;
        Expected_Indexes : constant array (1 .. 8) of Natural := (4, 9, 9, 2, 2, 1, 4, 3);
        All_Match : Boolean := True;
        begin
        Random_Sources.Draw_Unit (Dice, Unit);
        Check_Close ("primer número de la semilla 42", Unit, 0.5682303266439076);
        Random_Sources.Draw_Unit (Dice, Unit);
        Check_Close ("segundo número de la semilla 42", Unit, 0.2254634289477513);
        Random_Sources.Draw_Unit (Dice, Unit);
        Check_Close ("tercer número de la semilla 42", Unit, 0.41283831882951183);
        Dice := Random_Sources.Seeded (7);
        for Turn in Expected_Indexes'Range loop
            Random_Sources.Draw_Index (Dice, 10, Index);
            if Index /= Expected_Indexes (Turn) then
                All_Match := False;
                end if;
            end loop;
        Check ("ocho índices de la semilla 7", All_Match);
        end Test_Random_Sources;

    procedure Test_Alphabets is
        begin
        Check ("el alfabeto tiene 12 símbolos", Alphabets.Size (Letters) = 12);
        Check ("la primera letra vista recibe el símbolo 2", Symbol_For ('l') = 2);
        Check ("la segunda letra vista recibe el símbolo 3", Symbol_For ('a') = 3);
        Check ("el punto recibe el símbolo 12", Symbol_For ('.') = 12);
        Check ("una letra nunca vista es desconocida", Symbol_For ('z') = Unknown);
        Check ("del símbolo 5 se vuelve a la letra c", Alphabets.Character_Of (Letters, 5) = 'c');
        Check ("codificar y descodificar devuelve el texto", Texts.Decoded (Corpus, Letters) = Corpus_Text);
        end Test_Alphabets;

    procedure Test_Distributions is
        Even  : constant Distributions.Distribution := Distributions.Uniform (4);
        Tally : Distributions.Distribution := Distributions.Zero (4);
        begin
        Distributions.Set_Weight (Tally, 1, 1.0);
        Distributions.Set_Weight (Tally, 2, 3.0);
        Distributions.Set_Weight (Tally, 3, 0.0);
        Distributions.Set_Weight (Tally, 4, 4.0);
        Check_Close ("entropía de 4 letras iguales = ln 4", Distributions.Entropy (Even), 1.3862943611198906);
        Check_Close ("total de pesos", Distributions.Total (Tally), 8.0);
        Check ("variedad: 3 letras con peso", Distributions.Variety (Tally) = 3);
        Check ("la más probable es la 4", Distributions.Most_Likely (Tally) = 4);
        Check_Close ("entropía de (1, 3, 0, 4)", Distributions.Entropy (Tally), 0.9743147528693494);
        Check_Close ("sorpresa de la letra 2", Distributions.Surprise_Of (Tally, 2), 0.9808292530117262);
        Check_Close ("sorpresa de una letra imposible", Distributions.Surprise_Of (Tally, 3), 690.7755278982137);
        Check ("dado en 0.000 -> letra 1", Distributions.Sampled (Tally, 0.0) = 1);
        Check ("dado en 0.124 -> letra 1", Distributions.Sampled (Tally, 0.124) = 1);
        Check ("dado en 0.126 -> letra 2", Distributions.Sampled (Tally, 0.126) = 2);
        Check ("dado en 0.490 -> letra 2", Distributions.Sampled (Tally, 0.49) = 2);
        Check ("dado en 0.510 -> letra 4 (la 3 es imposible)", Distributions.Sampled (Tally, 0.51) = 4);
        Check ("dado en 0.999 -> letra 4", Distributions.Sampled (Tally, 0.999) = 4);
        declare
            Mixed  : constant Distributions.Distribution := Tally + 2.0 * Even;
            Shares : constant Distributions.Distribution := Distributions.Normalized (Tally);
            begin
            Check_Close ("álgebra: Tally + 2.0 * Even, letra 1", Distributions.Weight_Of (Mixed, 1), 1.5);
            Check_Close ("álgebra: Tally + 2.0 * Even, letra 3", Distributions.Weight_Of (Mixed, 3), 0.5);
            Check_Close ("normalizar: letra 2", Distributions.Weight_Of (Shares, 2), 0.375);
            Check_Close ("normalizar: suma 1", Distributions.Total (Shares), 1.0);
            end;
        end Test_Distributions;

    procedure Test_Fragment_Counts is
        begin
        Check ("187 fragmentos distintos", Counting_Oracles.Fragment_Total (Model) = 187);
        Check ("la letra a aparece 29 veces", Seen ("a") = 29);
        Check ("el fragmento la aparece 12 veces", Seen ("la") = 12);
        Check ("el fragmento casa aparece 5 veces", Seen ("casa") = 5);
        Check ("el fragmento rosa. aparece 1 vez", Seen ("rosa.") = 1);
        Check ("un fragmento nunca visto cuenta 0", Seen ("xx") = 0);
        Check ("un fragmento con espacios: 6 veces", Seen (" de l") = 6);
        end Test_Fragment_Counts;

    procedure Test_Opinions is
        Both_Sides : constant Canvases.Canvas := Templates.Parsed ("la c_sa de", Letters);
        Alone      : constant Canvases.Canvas := Templates.Parsed ("_", Letters);
        Left_Only  : constant Canvases.Canvas := Templates.Parsed ("la ros_", Letters);
        begin
        declare
            Belief : constant Distributions.Distribution := Model.Opinion (Both_Sides, 5);
            begin
            Check_Close ("dos lados: P(a)", Distributions.Probability_Of (Belief, Symbol_For ('a')), 0.7633265411439716);
            Check_Close ("dos lados: P(o)", Distributions.Probability_Of (Belief, Symbol_For ('o')), 0.2355700126736941);
            Check_Close ("dos lados: entropía", Distributions.Entropy (Belief), 0.556390935921461);
            Check ("dos lados: la más probable es a", Distributions.Most_Likely (Belief) = Symbol_For ('a'));
            Check_Close ("la opinión suma 1", Distributions.Total (Belief), 1.0);
            end;
        declare
            Belief : constant Distributions.Distribution := Model.Opinion (Alone, 1);
            begin
            Check_Close ("sin vecinas: P(a)", Distributions.Probability_Of (Belief, Symbol_For ('a')), 0.18131313131313131);
            Check_Close ("sin vecinas: entropía", Distributions.Entropy (Belief), 2.1766977283465896);
            end;
        declare
            Belief : constant Distributions.Distribution := Model.Opinion (Left_Only, 7);
            begin
            Check_Close ("solo izquierda: P(a)", Distributions.Probability_Of (Belief, Symbol_For ('a')), 0.9628293807641635);
            end;
        end Test_Opinions;

    procedure Test_Templates is
        Board : constant Canvases.Canvas := Templates.Parsed ("la [3]_ [...]fin\n[x]", Letters);
        Plain : constant Canvases.Canvas := Templates.Parsed ("la casa", Letters);
        begin
        Check ("plantilla: 45 celdas", Canvases.Length (Board) = 45);
        Check ("plantilla: 34 huecos", Canvases.Blank_Count (Board) = 34);
        Check ("pintar una plantilla sin huecos la devuelve igual", Templates.Rendered (Plain, Letters) = "la casa");
        Check ("un corchete sin número no es un hueco", Canvases.State_At (Board, 43) = Canvases.Given);
        end Test_Templates;

    procedure Test_Collapsing is
        Template : constant Wide_Wide_String := "la [12] rosa.";
        Board    : Canvases.Canvas := Templates.Parsed (Template, Letters);
        Dice     : Random_Sources.Generator := Random_Sources.Seeded (1);
        begin
        Collapsing.Collapse_All (Board, Model, Dice);
        Check ("tras colapsar no quedan huecos", Canvases.Blank_Count (Board) = 0);
        Check ("tras colapsar hay 12 letras del modelo", Canvases.Guess_Count (Board) = 12);
        Check ("colapsar no toca las letras dadas", Givens_Kept (Board, Template));
        Check_Mirror ("colapso, semilla 1", Templates.Rendered (Board, Letters, True), "la [costa. es la] rosa.");

        Board := Templates.Parsed (Template, Letters);
        Dice := Random_Sources.Seeded (1);
        Collapsing.Collapse_All (Board, Model, Dice, Collapsing.Left_To_Right, Collapsing.Always_Most_Likely);
        Check_Mirror ("izquierda a derecha sin sorteo", Templates.Rendered (Board, Letters, True), "la [casa de la l] rosa.");

        Board := Templates.Parsed (Template, Letters);
        Dice := Random_Sources.Seeded (5);
        Collapsing.Collapse_All (Board, Model, Dice, Collapsing.At_Random);
        Check ("orden al azar: no quedan huecos", Canvases.Blank_Count (Board) = 0);
        Check_Mirror ("orden al azar, semilla 5", Templates.Rendered (Board, Letters, True), "la [olasa. ela o] rosa.");
        end Test_Collapsing;

    procedure Test_Repairing is
        Template : constant Wide_Wide_String := "la cos_del oso";
        Board    : Canvases.Canvas := Templates.Parsed (Template, Letters);
        Dice     : Random_Sources.Generator := Random_Sources.Seeded (3);
        Options  : constant Repairing.Settings := Repairing.Default_Settings;
        Outcome  : Repairing.Report;
        Before   : Long_Float;
        begin
        Collapsing.Collapse_All (Board, Model, Dice);
        Before := Repairing.Tension (Board, Model, Options.Tolerance);
        Repairing.Relax (Board, Model, Dice, Outcome, Options);
        Check ("reparar nunca sube la tensión", Outcome.Final_Tension <= Before);
        Check ("reparar no toca las letras dadas", Givens_Kept (Board, Template));
        Check ("tras reparar no quedan huecos", Canvases.Blank_Count (Board) = 0);
        Check_Close ("la tensión final es la del lienzo", Repairing.Tension (Board, Model, Options.Tolerance), Outcome.Final_Tension);
        Check_Mirror ("un hueco demasiado corto crece", Templates.Rendered (Board, Letters, True), "la cos[asa ]del oso");
        if Outcome.Widenings = 1 then
            Console.Put_Line ("  ok     el arreglo fue un ensanche, como en la referencia");
        else
            Console.Put_Line ("  AVISO  el arreglo no fue un ensanche (en la referencia sí)");
            Warnings := Warnings + 1;
            end if;
        end Test_Repairing;

    procedure Test_Blind_Spots is
        Original : constant Canvases.Canvas := Templates.From_Text (Corpus, 1, 60);
        Board    : Canvases.Canvas := Original;
        Dice     : Random_Sources.Generator := Random_Sources.Seeded (9);
        Result   : Blind_Spots.Score;
        begin
        Blind_Spots.Hide_At_Random (Board, 0.3, Dice);
        Check ("se tapan 22 letras de 60", Canvases.Blank_Count (Board) = 22);
        Collapsing.Collapse_All (Board, Model, Dice, Collapsing.Most_Certain_First, Collapsing.Always_Most_Likely);
        Result := Blind_Spots.Scored (Board, Original);
        Check ("se puntúan las 22 letras tapadas", Result.Hidden = 22);
        Check ("se recuperan 20 de 22", Result.Recovered = 20);
        end Test_Blind_Spots;

    procedure Test_Voting_Oracles is
        Board    : constant Canvases.Canvas := Templates.Parsed ("la c_sa de", Letters);
        Letter_A : constant Symbol := Symbol_For ('a');
        Scores   : constant Distributions.Score_Array (1 .. 4) := (0.0, 1.0, -1.0, 2.0);
        Shares   : constant Distributions.Distribution := Distributions.From_Scores (Scores);
        Pupil    : Voting_Oracles.Voting_Oracle;
        Plan     : Voting_Oracles.Lesson_Plan := Voting_Oracles.Default_Plan;
        Dice     : Random_Sources.Generator := Random_Sources.Seeded (11);
        Surprise : Long_Float;
        Result   : Blind_Spots.Exam_Result;
        Filled   : Canvases.Canvas := Templates.Parsed ("la [12] rosa.", Letters);
        begin
        Check_Close ("puntos a probabilidades: letra 1", Distributions.Weight_Of (Shares, 1), 0.08714431874203257);
        Check_Close ("puntos a probabilidades: letra 4", Distributions.Weight_Of (Shares, 4), 0.6439142598879724);
        Check_Close ("puntos a probabilidades: suma 1", Distributions.Total (Shares), 1.0);

        Voting_Oracles.Prepare (Pupil, Alphabets.Size (Letters), 3);
        declare
            Belief : constant Distributions.Distribution := Pupil.Opinion (Board, 5);
            begin
            Check_Close ("sin entrenar: todas las letras por igual", Distributions.Probability_Of (Belief, Letter_A), 0.08333333333333333);
            end;
        Voting_Oracles.Learn_Cell (Pupil, Board, 5, Letter_A, 0.5, Surprise);
        Check_Close ("primera lección: sorpresa = ln 12", Surprise, 2.4849066497880004);
        declare
            Belief : constant Distributions.Distribution := Pupil.Opinion (Board, 5);
            begin
            Check_Close ("tras una lección la letra real es más probable", Distributions.Probability_Of (Belief, Letter_A), 0.13034687344398008);
            end;

        Voting_Oracles.Prepare (Pupil, Alphabets.Size (Letters), 3);
        Plan.Lessons := 60;
        Plan.Piece_Length := 24;
        Voting_Oracles.Train (Pupil, Corpus, Dice, Surprise, Plan);
        Check_Close ("entrenar 60 lecciones: sorpresa final", Surprise, 1.915541972753829);
        declare
            Belief : constant Distributions.Distribution := Pupil.Opinion (Board, 5);
            begin
            Check_Close ("entrenado: P(a)", Distributions.Probability_Of (Belief, Letter_A), 0.797228557731476);
            Check ("entrenado: la más probable es a", Distributions.Most_Likely (Belief) = Letter_A);
            end;

        Dice := Random_Sources.Seeded (4);
        Blind_Spots.Examine (Model, Corpus, Dice, 5, 24, 0.4, Result);
        Check ("examen del conteo: 35 aciertos de 45", Result.Hidden = 45 and then Result.Hits = 35);
        Check_Close ("examen del conteo: sorpresa media", Blind_Spots.Mean_Surprise (Result), 0.6231927485060871);
        Dice := Random_Sources.Seeded (4);
        Blind_Spots.Examine (Pupil, Corpus, Dice, 5, 24, 0.4, Result);
        Check ("examen de los votos: 28 aciertos de 45", Result.Hidden = 45 and then Result.Hits = 28);
        Check_Close ("examen de los votos: sorpresa media", Blind_Spots.Mean_Surprise (Result), 1.0526600853953112);

        Dice := Random_Sources.Seeded (1);
        Collapsing.Collapse_All (Filled, Pupil, Dice);
        Check ("el motor colapsa igual con otro cerebro", Canvases.Blank_Count (Filled) = 0);
        Check_Mirror ("colapso con votos, semilla 1", Templates.Rendered (Filled, Letters, True), "la [casasasde la] rosa.");
        end Test_Voting_Oracles;

    begin
    Prepare;
    Run_Group ("Azar repetible", Test_Random_Sources'Access);
    Run_Group ("Alfabeto", Test_Alphabets'Access);
    Run_Group ("Distribuciones", Test_Distributions'Access);
    Run_Group ("Cuenta de fragmentos", Test_Fragment_Counts'Access);
    Run_Group ("Opiniones del modelo", Test_Opinions'Access);
    Run_Group ("Plantillas", Test_Templates'Access);
    Run_Group ("Colapso", Test_Collapsing'Access);
    Run_Group ("Reparar y crecer", Test_Repairing'Access);
    Run_Group ("Puntos ciegos", Test_Blind_Spots'Access);
    Run_Group ("Cerebro de votos", Test_Voting_Oracles'Access);
    Console.Put_Line ("");
    Console.Put_Line ("Fallos: " & Console.Image (Failures) & "   Avisos: " & Console.Image (Warnings));
    if Failures > 0 then
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
        end if;
    end Colapso_Tests;
