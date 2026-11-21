--  Tests for Calipso.
--
--  Two kinds of check:
--
--     Check        : must always hold. If it fails, the program ends with an error.
--     Check_Mirror : compares with what the Python reference gave with the same
--                    seed. If it differs it only leaves a note, because a rounding
--                    difference between machines can change a draw without anything being wrong.
--
--  The expected values come from reference/tests.py (same corpus, same steps).

with Ada.Command_Line;
with Ada.Exceptions;

with Calipso.Alphabets;
with Calipso.Blind_Spots;
with Calipso.Canvases;
with Calipso.Collapsing;
with Calipso.Console;
with Calipso.Counting_Oracles;
with Calipso.Distributions;
with Calipso.Fragment_Counts;
with Calipso.Random_Sources;
with Calipso.Repairing;
with Calipso.Templates;
with Calipso.Texts;
with Calipso.Voting_Oracles;

procedure Calipso_Tests is

    use Calipso;
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
            Console.Put_Line ("  FAIL   " & Name);
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
            Console.Put_Line ("         got " & Console.Image (Actual, 12));
            Console.Put_Line ("         expected " & Console.Image (Expected, 12));
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
            Console.Put_Line ("  NOTE   " & Name & " (differs from the reference)");
            Console.Put_Wide_Line ("         got " & Actual);
            Console.Put_Wide_Line ("         expected " & Expected);
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
            Console.Put_Line ("  FAIL   exception: " & Ada.Exceptions.Exception_Information (Problem));
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
    --# Are all the given letters of the template still on the canvas, in the same order?

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
        Check_Close ("first number from seed 42", Unit, 0.5682303266439076);
        Random_Sources.Draw_Unit (Dice, Unit);
        Check_Close ("second number from seed 42", Unit, 0.2254634289477513);
        Random_Sources.Draw_Unit (Dice, Unit);
        Check_Close ("third number from seed 42", Unit, 0.41283831882951183);
        Dice := Random_Sources.Seeded (7);
        for Turn in Expected_Indexes'Range loop
            Random_Sources.Draw_Index (Dice, 10, Index);
            if Index /= Expected_Indexes (Turn) then
                All_Match := False;
                end if;
            end loop;
        Check ("eight indexes from seed 7", All_Match);
        end Test_Random_Sources;

    procedure Test_Alphabets is
        begin
        Check ("the alphabet has 12 symbols", Alphabets.Size (Letters) = 12);
        Check ("the first letter seen gets symbol 2", Symbol_For ('l') = 2);
        Check ("the second letter seen gets symbol 3", Symbol_For ('a') = 3);
        Check ("the full stop gets symbol 12", Symbol_For ('.') = 12);
        Check ("a letter never seen is unknown", Symbol_For ('z') = Unknown);
        Check ("symbol 5 maps back to the letter c", Alphabets.Character_Of (Letters, 5) = 'c');
        Check ("encoding and decoding returns the text", Texts.Decoded (Corpus, Letters) = Corpus_Text);
        end Test_Alphabets;

    procedure Test_Distributions is
        Even  : constant Distributions.Distribution := Distributions.Uniform (4);
        Tally : Distributions.Distribution := Distributions.Zero (4);
        begin
        Distributions.Set_Weight (Tally, 1, 1.0);
        Distributions.Set_Weight (Tally, 2, 3.0);
        Distributions.Set_Weight (Tally, 3, 0.0);
        Distributions.Set_Weight (Tally, 4, 4.0);
        Check_Close ("entropy of 4 equal letters = ln 4", Distributions.Entropy (Even), 1.3862943611198906);
        Check_Close ("total weight", Distributions.Total (Tally), 8.0);
        Check ("variety: 3 letters with weight", Distributions.Variety (Tally) = 3);
        Check ("the most likely is letter 4", Distributions.Most_Likely (Tally) = 4);
        Check_Close ("entropy of (1, 3, 0, 4)", Distributions.Entropy (Tally), 0.9743147528693494);
        Check_Close ("surprise of letter 2", Distributions.Surprise_Of (Tally, 2), 0.9808292530117262);
        Check_Close ("surprise of an impossible letter", Distributions.Surprise_Of (Tally, 3), 690.7755278982137);
        Check ("dice at 0.000 -> letter 1", Distributions.Sampled (Tally, 0.0) = 1);
        Check ("dice at 0.124 -> letter 1", Distributions.Sampled (Tally, 0.124) = 1);
        Check ("dice at 0.126 -> letter 2", Distributions.Sampled (Tally, 0.126) = 2);
        Check ("dice at 0.490 -> letter 2", Distributions.Sampled (Tally, 0.49) = 2);
        Check ("dice at 0.510 -> letter 4 (letter 3 is impossible)", Distributions.Sampled (Tally, 0.51) = 4);
        Check ("dice at 0.999 -> letter 4", Distributions.Sampled (Tally, 0.999) = 4);
        declare
            Mixed  : constant Distributions.Distribution := Tally + 2.0 * Even;
            Shares : constant Distributions.Distribution := Distributions.Normalized (Tally);
            begin
            Check_Close ("algebra: Tally + 2.0 * Even, letter 1", Distributions.Weight_Of (Mixed, 1), 1.5);
            Check_Close ("algebra: Tally + 2.0 * Even, letter 3", Distributions.Weight_Of (Mixed, 3), 0.5);
            Check_Close ("normalize: letter 2", Distributions.Weight_Of (Shares, 2), 0.375);
            Check_Close ("normalize: sums to 1", Distributions.Total (Shares), 1.0);
            end;
        end Test_Distributions;

    procedure Test_Fragment_Counts is
        begin
        Check ("187 distinct fragments", Counting_Oracles.Fragment_Total (Model) = 187);
        Check ("the letter a appears 29 times", Seen ("a") = 29);
        Check ("the fragment la appears 12 times", Seen ("la") = 12);
        Check ("the fragment casa appears 5 times", Seen ("casa") = 5);
        Check ("the fragment rosa. appears once", Seen ("rosa.") = 1);
        Check ("a fragment never seen counts 0", Seen ("xx") = 0);
        Check ("a fragment with spaces: 6 times", Seen (" de l") = 6);
        end Test_Fragment_Counts;

    procedure Test_Opinions is
        Both_Sides : constant Canvases.Canvas := Templates.Parsed ("la c_sa de", Letters);
        Alone      : constant Canvases.Canvas := Templates.Parsed ("_", Letters);
        Left_Only  : constant Canvases.Canvas := Templates.Parsed ("la ros_", Letters);
        begin
        declare
            Belief : constant Distributions.Distribution := Model.Opinion (Both_Sides, 5);
            begin
            Check_Close ("both sides: P(a)", Distributions.Probability_Of (Belief, Symbol_For ('a')), 0.7633265411439716);
            Check_Close ("both sides: P(o)", Distributions.Probability_Of (Belief, Symbol_For ('o')), 0.2355700126736941);
            Check_Close ("both sides: entropy", Distributions.Entropy (Belief), 0.556390935921461);
            Check ("both sides: the most likely is a", Distributions.Most_Likely (Belief) = Symbol_For ('a'));
            Check_Close ("the opinion sums to 1", Distributions.Total (Belief), 1.0);
            end;
        declare
            Belief : constant Distributions.Distribution := Model.Opinion (Alone, 1);
            begin
            Check_Close ("no neighbours: P(a)", Distributions.Probability_Of (Belief, Symbol_For ('a')), 0.18131313131313131);
            Check_Close ("no neighbours: entropy", Distributions.Entropy (Belief), 2.1766977283465896);
            end;
        declare
            Belief : constant Distributions.Distribution := Model.Opinion (Left_Only, 7);
            begin
            Check_Close ("left side only: P(a)", Distributions.Probability_Of (Belief, Symbol_For ('a')), 0.9628293807641635);
            end;
        end Test_Opinions;

    procedure Test_Templates is
        Board : constant Canvases.Canvas := Templates.Parsed ("la [3]_ [...]fin\n[x]", Letters);
        Plain : constant Canvases.Canvas := Templates.Parsed ("la casa", Letters);
        begin
        Check ("template: 45 cells", Canvases.Length (Board) = 45);
        Check ("template: 34 holes", Canvases.Blank_Count (Board) = 34);
        Check ("rendering a template with no holes returns it unchanged", Templates.Rendered (Plain, Letters) = "la casa");
        Check ("a bracket without a number is not a hole", Canvases.State_At (Board, 43) = Canvases.Given);
        end Test_Templates;

    procedure Test_Collapsing is
        Template : constant Wide_Wide_String := "la [12] rosa.";
        Board    : Canvases.Canvas := Templates.Parsed (Template, Letters);
        Dice     : Random_Sources.Generator := Random_Sources.Seeded (1);
        begin
        Collapsing.Collapse_All (Board, Model, Dice);
        Check ("after collapsing no holes are left", Canvases.Blank_Count (Board) = 0);
        Check ("after collapsing there are 12 model letters", Canvases.Guess_Count (Board) = 12);
        Check ("collapsing does not touch the given letters", Givens_Kept (Board, Template));
        Check_Mirror ("collapse, seed 1", Templates.Rendered (Board, Letters, True), "la [costa. es la] rosa.");

        Board := Templates.Parsed (Template, Letters);
        Dice := Random_Sources.Seeded (1);
        Collapsing.Collapse_All (Board, Model, Dice, Collapsing.Left_To_Right, Collapsing.Always_Most_Likely);
        Check_Mirror ("left to right without drawing lots", Templates.Rendered (Board, Letters, True), "la [casa de la l] rosa.");

        Board := Templates.Parsed (Template, Letters);
        Dice := Random_Sources.Seeded (5);
        Collapsing.Collapse_All (Board, Model, Dice, Collapsing.At_Random);
        Check ("random order: no holes are left", Canvases.Blank_Count (Board) = 0);
        Check_Mirror ("random order, seed 5", Templates.Rendered (Board, Letters, True), "la [olasa. ela o] rosa.");
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
        Check ("repair never raises the tension", Outcome.Final_Tension <= Before);
        Check ("repair does not touch the given letters", Givens_Kept (Board, Template));
        Check ("after repair no holes are left", Canvases.Blank_Count (Board) = 0);
        Check_Close ("the final tension is the tension of the canvas", Repairing.Tension (Board, Model, Options.Tolerance), Outcome.Final_Tension);
        Check_Mirror ("a hole that is too short grows", Templates.Rendered (Board, Letters, True), "la cos[asa ]del oso");
        if Outcome.Widenings = 1 then
            Console.Put_Line ("  ok     the fix was a widening, as in the reference");
        else
            Console.Put_Line ("  NOTE   the fix was not a widening (it was in the reference)");
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
        Check ("22 letters out of 60 are hidden", Canvases.Blank_Count (Board) = 22);
        Collapsing.Collapse_All (Board, Model, Dice, Collapsing.Most_Certain_First, Collapsing.Always_Most_Likely);
        Result := Blind_Spots.Scored (Board, Original);
        Check ("the 22 hidden letters are scored", Result.Hidden = 22);
        Check ("20 out of 22 are recovered", Result.Recovered = 20);
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
        Check_Close ("scores to probabilities: letter 1", Distributions.Weight_Of (Shares, 1), 0.08714431874203257);
        Check_Close ("scores to probabilities: letter 4", Distributions.Weight_Of (Shares, 4), 0.6439142598879724);
        Check_Close ("scores to probabilities: sums to 1", Distributions.Total (Shares), 1.0);

        Voting_Oracles.Prepare (Pupil, Alphabets.Size (Letters), 3);
        declare
            Belief : constant Distributions.Distribution := Pupil.Opinion (Board, 5);
            begin
            Check_Close ("untrained: all letters equally likely", Distributions.Probability_Of (Belief, Letter_A), 0.08333333333333333);
            end;
        Voting_Oracles.Learn_Cell (Pupil, Board, 5, Letter_A, 0.5, Surprise);
        Check_Close ("first lesson: surprise = ln 12", Surprise, 2.4849066497880004);
        declare
            Belief : constant Distributions.Distribution := Pupil.Opinion (Board, 5);
            begin
            Check_Close ("after one lesson the real letter is more likely", Distributions.Probability_Of (Belief, Letter_A), 0.13034687344398008);
            end;

        Voting_Oracles.Prepare (Pupil, Alphabets.Size (Letters), 3);
        Plan.Lessons := 60;
        Plan.Piece_Length := 24;
        Voting_Oracles.Train (Pupil, Corpus, Dice, Surprise, Plan);
        Check_Close ("training 60 lessons: final surprise", Surprise, 1.915541972753829);
        declare
            Belief : constant Distributions.Distribution := Pupil.Opinion (Board, 5);
            begin
            Check_Close ("trained: P(a)", Distributions.Probability_Of (Belief, Letter_A), 0.797228557731476);
            Check ("trained: the most likely is a", Distributions.Most_Likely (Belief) = Letter_A);
            end;

        Dice := Random_Sources.Seeded (4);
        Blind_Spots.Examine (Model, Corpus, Dice, 5, 24, 0.4, Result);
        Check ("counting exam: 35 hits out of 45", Result.Hidden = 45 and then Result.Hits = 35);
        Check_Close ("counting exam: mean surprise", Blind_Spots.Mean_Surprise (Result), 0.6231927485060871);
        Dice := Random_Sources.Seeded (4);
        Blind_Spots.Examine (Pupil, Corpus, Dice, 5, 24, 0.4, Result);
        Check ("voting exam: 28 hits out of 45", Result.Hidden = 45 and then Result.Hits = 28);
        Check_Close ("voting exam: mean surprise", Blind_Spots.Mean_Surprise (Result), 1.0526600853953112);

        Dice := Random_Sources.Seeded (1);
        Collapsing.Collapse_All (Filled, Pupil, Dice);
        Check ("the engine collapses the same with another brain", Canvases.Blank_Count (Filled) = 0);
        Check_Mirror ("collapse with votes, seed 1", Templates.Rendered (Filled, Letters, True), "la [casasasde la] rosa.");
        end Test_Voting_Oracles;

    begin
    Prepare;
    Run_Group ("Repeatable randomness", Test_Random_Sources'Access);
    Run_Group ("Alphabet", Test_Alphabets'Access);
    Run_Group ("Distributions", Test_Distributions'Access);
    Run_Group ("Fragment counts", Test_Fragment_Counts'Access);
    Run_Group ("Model opinions", Test_Opinions'Access);
    Run_Group ("Templates", Test_Templates'Access);
    Run_Group ("Collapse", Test_Collapsing'Access);
    Run_Group ("Repair and grow", Test_Repairing'Access);
    Run_Group ("Blind spots", Test_Blind_Spots'Access);
    Run_Group ("Voting brain", Test_Voting_Oracles'Access);
    Console.Put_Line ("");
    Console.Put_Line ("Failures: " & Console.Image (Failures) & "   Notes: " & Console.Image (Warnings));
    if Failures > 0 then
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
        end if;
    end Calipso_Tests;
