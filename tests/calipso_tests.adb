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
with Ada.Containers;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Wide_Wide_Unbounded;

with Calipso.Alphabets;
with Calipso.Basis_Neurons;
with Calipso.Bias_Neurons;
with Calipso.Blind_Spots;
with Calipso.Brains;
with Calipso.Canvases;
with Calipso.Collapsing;
with Calipso.Console;
with Calipso.Counting_Neurons;
with Calipso.Counting_Oracles;
with Calipso.Criteria;
with Calipso.Distributions;
with Calipso.File_Sources;
with Calipso.Folder_Fetchers;
with Calipso.Fragment_Counts;
with Calipso.Memory_Sources;
with Calipso.Neuron_Kinds;
with Calipso.Neurons;
with Calipso.Numbers;
with Calipso.Oracles;
with Calipso.Pages;
with Calipso.Random_Sources;
with Calipso.Records;
with Calipso.Repairing;
with Calipso.Robots;
with Calipso.Templates;
with Calipso.Texts;
with Calipso.Web_Addresses;
with Calipso.Web_Sources;

procedure Calipso_Tests is

    use Calipso;
    use type Ada.Containers.Hash_Type;
    use type Canvases.Cell_State;
    use type Distributions.Distribution;
    use type Pages.Block_Kind;
    use type Texts.Symbol_Text;
    use type Web_Addresses.Content_Kind;

    package Wide_Texts renames Ada.Strings.Wide_Wide_Unbounded;

    Corpus_Text : constant Wide_Wide_String :=
        "la casa de la costa es la casa de la rosa. la rosa de la casa es la cosa de la costa. "
        & "el oso de la rosa es el oso de la casa. la casa del oso es la costa.";

    Test_Longest : constant Positive := 5;
    Saved_Brain  : constant String := "brain_test_saved.brn";
    Saved_Tape   : constant String := "tape_test_saved.brn";
    Packed_Tape  : constant String := "tape_test_saved.zmb";
    Packed_Brain : constant String := "tests/data/brain_from_python.zmb";
    Python_Brain : constant String := "tests/data/brain_from_python.brn";
    Sample_File  : constant String := "data/sample_es.txt";
    Test_Site    : constant String := "http://test.site";
    Site_Folder  : constant String := "tests/site";
    Page_Work_File : constant String := "page_test_work.tmp";
    --# The tests are run from the top folder of the project.
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

    procedure Test_Bounded_Memory is
        Table : Fragment_Counts.Count_Table;
        begin
        Fragment_Counts.Limit (Table, 1_000);
        Fragment_Counts.Learn (Table, Corpus, Test_Longest);
        Check ("bounded memory: la appears 12 times", Fragment_Counts.Count_Of (Table, Piece_Of ("la")) = 12);
        Check ("bounded memory: casa appears 5 times", Fragment_Counts.Count_Of (Table, Piece_Of ("casa")) = 5);
        Check ("bounded memory: 173 counters in use", Fragment_Counts.Distinct_Fragments (Table) = 173);
        Check ("bounded memory: the scrambled number of la", Fragment_Counts.Hash (Piece_Of ("la")) = 1_585_155_634);
        Check ("bounded memory: the check number of la", Fragment_Counts.Check_Of (Piece_Of ("la")) = 1_123_950_074);
        Check (
            "bounded memory: a fragment never seen reads 0, even where a counter is taken",
            Fragment_Counts.Count_Of (Table, Piece_Of ("laa")) = 0
            );
        end Test_Bounded_Memory;

    procedure Test_Basis_Neurons is
        Size     : constant Symbol := Alphabets.Size (Letters);
        Waves    : Basis_Neurons.Basis_Neuron;
        Fading   : Basis_Neurons.Basis_Neuron;
        Exact    : Basis_Neurons.Basis_Neuron;
        Presence : constant Neurons.Neuron'Class := Neuron_Kinds.Made ("presence", Size);
        begin
        Basis_Neurons.Prepare (Waves, Size, Basis_Neurons.By_Harmonic, 3, 2);
        Basis_Neurons.Prepare (Fading, Size, Basis_Neurons.By_Decay, 3, 2);
        Basis_Neurons.Prepare (Exact, Size, Basis_Neurons.By_Position, 3, 0);
        --# Mirror note: curves count from 1 here and from 0 in Python.
        Check_Close ("harmonic: the first curve is flat", Basis_Neurons.Curve_Height (Waves, 1, 2), 1.0);
        Check_Close ("harmonic: cosine of the first wave", Basis_Neurons.Curve_Height (Waves, 2, 1), 0.6234898018587336);
        Check_Close ("harmonic: sine of the first wave", Basis_Neurons.Curve_Height (Waves, 3, -2), -0.9749279121818236);
        Check_Close ("harmonic: cosine of the second wave", Basis_Neurons.Curve_Height (Waves, 4, 3), 0.6234898018587334);
        Check_Close ("decay: the nearest neighbour counts 1", Basis_Neurons.Curve_Height (Fading, 1, -1), 1.0);
        Check_Close ("decay: slow fading at distance 3", Basis_Neurons.Curve_Height (Fading, 2, -3), 0.36787944117144233);
        Check_Close ("decay: a right curve at distance 2", Basis_Neurons.Curve_Height (Fading, 3, 2), 0.36787944117144233);
        Check_Close ("decay: a left curve ignores the right side", Basis_Neurons.Curve_Height (Fading, 1, 2), 0.0);
        Check_Close ("position: a curve is 1 at its own distance", Basis_Neurons.Curve_Height (Exact, 4, 1), 1.0);
        Check_Close ("position: and 0 at any other", Basis_Neurons.Curve_Height (Exact, 4, 2), 0.0);
        Check ("the presence neuron is a harmonic neuron with no waves", Presence.Name = "presence");
        end Test_Basis_Neurons;

    procedure Build_Small_Brain (
            Pupil : in out Brains.Brain
            ) is
        Size  : constant Symbol := Alphabets.Size (Letters);
        Bias  : Bias_Neurons.Bias_Neuron;
        Exact : Basis_Neurons.Basis_Neuron;
        begin
        Brains.Prepare (Pupil, Letters);
        Bias_Neurons.Prepare (Bias, Size);
        Brains.Add_Neuron (Pupil, Bias);
        Basis_Neurons.Prepare (Exact, Size, Basis_Neurons.By_Position, 3, 0);
        Brains.Add_Neuron (Pupil, Exact);
        end Build_Small_Brain;
    --# A brain small enough for the tiny corpus: starting points plus exact distances up to 3.

    procedure Study_From_Corpus (
            Pupil   : in out Brains.Brain;
            Lessons : in     Natural;
            Result  :    out Blind_Spots.Exam_Result
            ) is
        Reader : Memory_Sources.Memory_Source;
        Dice   : Random_Sources.Generator := Random_Sources.Seeded (11);
        begin
        Memory_Sources.Open (Reader, Corpus, 24, 7);
        Brains.Study (Pupil, Reader, Dice, Lessons, Result);
        end Study_From_Corpus;

    procedure Build_Mixed_Brain (
            Pupil : in out Brains.Brain
            ) is
        Unused : Blind_Spots.Exam_Result;
        --# The score of these lessons is not needed here; only the trained brain is.
        --# (The compiler knows a variable called Unused is meant to be left alone.)
        begin
        Brains.Prepare (Pupil, Letters);
        Brains.Add_Recipe (Pupil, "bias+presence+harmonic+decay+counting");
        Study_From_Corpus (Pupil, 30, Unused);
        end Build_Mixed_Brain;

    function Recipe_Is_Refused (
            Recipe : in String
            ) return Boolean is
        Pupil : Brains.Brain;
        begin
        Brains.Prepare (Pupil, Letters);
        Brains.Add_Recipe (Pupil, Recipe);
        return False;
        exception
        when Neuron_Kinds.Recipe_Error =>
            return True;
        end Recipe_Is_Refused;

    function Opinion_On_A (
            Model : in Oracles.Oracle'Class
            ) return Long_Float is
        Board  : constant Canvases.Canvas := Templates.Parsed ("la c_sa de", Letters);
        Belief : constant Distributions.Distribution := Model.Opinion (Board, 5);
        begin
        return Distributions.Probability_Of (Belief, Symbol_For ('a'));
        end Opinion_On_A;
    --# What the model bets on the letter a in "la c_sa de".

    procedure Test_Brains is
        Scores   : constant Distributions.Score_Array (1 .. 4) := (0.0, 1.0, -1.0, 2.0);
        Shares   : constant Distributions.Distribution := Distributions.From_Scores (Scores);
        Pupil    : Brains.Brain;
        Restored : Brains.Brain;
        Foreign  : Brains.Brain;
        Mixed    : Brains.Brain;
        Unpacked : Brains.Brain;
        Sized    : Brains.Brain;
        Usual_Waves : constant Neurons.Neuron'Class := Neuron_Kinds.Made ("harmonic:12:4", Alphabets.Size (Letters));
        Counter  : Brains.Brain;
        Lone     : Counting_Neurons.Counting_Neuron;
        Teacher  : Counting_Oracles.Counting_Oracle;
        Result   : Blind_Spots.Exam_Result;
        begin
        Check_Close ("scores to probabilities: letter 1", Distributions.Weight_Of (Shares, 1), 0.08714431874203257);
        Check_Close ("scores to probabilities: letter 4", Distributions.Weight_Of (Shares, 4), 0.6439142598879724);
        Check_Close ("scores to probabilities: sums to 1", Distributions.Total (Shares), 1.0);

        Build_Small_Brain (Pupil);
        Check_Close ("untrained: all letters equally likely", Opinion_On_A (Pupil), 0.08333333333333333);
        Study_From_Corpus (Pupil, 60, Result);
        Check ("studying 60 lessons tests 648 letters and gets 237 right", Result.Hidden = 648 and then Result.Hits = 237);
        Check_Close ("studying 60 lessons: mean surprise", Blind_Spots.Mean_Surprise (Result), 1.994014327824858);
        Check_Close ("after studying: P(a)", Opinion_On_A (Pupil), 0.1852612847565514);
        Check ("the brain knows its recipe", Brains.Recipe_Of (Pupil) = "bias+position:3");
        Check ("the brain counts its lessons", Brains.Lessons_Studied (Pupil) = 60);
        Check ("the reach of a brain is that of its widest neuron", Pupil.Reach = 3);

        Brains.Save (Pupil, Saved_Brain);
        Brains.Load (Restored, Saved_Brain);
        Ada.Directories.Delete_File (Saved_Brain);
        Check_Close ("saved and loaded: the same opinion", Opinion_On_A (Restored), Opinion_On_A (Pupil));
        Check (
            "saved and loaded: the same recipe and lessons",
            Brains.Recipe_Of (Restored) = "bias+position:3" and then Brains.Lessons_Studied (Restored) = 60
            );

        Brains.Load (Foreign, Python_Brain);
        Check_Close ("a brain saved by Python: P(a)", Opinion_On_A (Foreign), 0.1852612847565514);
        Check (
            "a brain saved by Python: recipe and lessons",
            Brains.Recipe_Of (Foreign) = "bias+position:3" and then Brains.Lessons_Studied (Foreign) = 60
            );

        Brains.Load (Unpacked, Packed_Brain);
        Check_Close ("a packed brain saved by Python: P(a)", Opinion_On_A (Unpacked), 0.1852612847565514);

        Brains.Prepare (Sized, Letters);
        Brains.Add_Recipe (Sized, "bias+position:5+decay:6:2+memory:4096:5");
        Check (
            "a recipe can give sizes, and the brain says them back",
            Brains.Recipe_Of (Sized) = "bias+position:5+decay:6:2+memory:4096:5"
            );
        Check ("the usual sizes are not written", Usual_Waves.Name = "harmonic");
        Check ("the reach of a sized brain", Sized.Reach = 6);
        Check ("a size of 0 is refused", Recipe_Is_Refused ("position:0"));
        Check ("a size where none belongs is refused", Recipe_Is_Refused ("bias:3"));

        Brains.Prepare (Mixed, Letters);
        Brains.Add_Recipe (Mixed, "bias+presence+harmonic+decay+counting");
        Study_From_Corpus (Mixed, 30, Result);
        Check ("five kinds of neuron in one brain: 142 right out of 326", Result.Hidden = 326 and then Result.Hits = 142);
        Check_Close ("five kinds of neuron: mean surprise", Blind_Spots.Mean_Surprise (Result), 1.5310978676143332);
        Check_Close ("five kinds of neuron: P(a)", Opinion_On_A (Mixed), 0.6032365023141226);
        Check ("five kinds of neuron: recipe", Brains.Recipe_Of (Mixed) = "bias+presence+harmonic+decay+counting");

        Counting_Neurons.Prepare (Lone, Alphabets.Size (Letters));
        Lone.Learn_From_Text (Corpus);
        Brains.Prepare (Counter, Letters);
        Brains.Add_Neuron (Counter, Lone);
        Counting_Oracles.Train (Teacher, Corpus, Alphabets.Size (Letters));
        Check_Close (
            "a brain with only the counting neuron says what the counting oracle says",
            Opinion_On_A (Counter),
            Opinion_On_A (Teacher)
            );
        Check ("a recipe with an unknown name is refused", Recipe_Is_Refused ("bias+nonsense"));
        end Test_Brains;

    procedure Test_Criteria is
        Template     : constant Wide_Wide_String := "la [12] rosa.";
        Board        : constant Canvases.Canvas := Templates.Parsed ("la c_sa de", Letters);
        By_Certainty : constant Criteria.Certainty := (null record);
        By_Agreement : constant Criteria.Agreement := (null record);
        By_Leftmost  : constant Criteria.Leftmost := (null record);
        --# These three criteria hold no data: all that matters is which one it is.
        Mix          : Criteria.Mixed;
        Mixed_Brain  : Brains.Brain;
        Filled       : Canvases.Canvas := Templates.Parsed (Template, Letters);
        Dice         : Random_Sources.Generator := Random_Sources.Seeded (1);
        begin
        Build_Mixed_Brain (Mixed_Brain);
        Check_Close ("certainty of a hole with both sides known", By_Certainty.Readiness (Board, Model, 5), 0.7760918157754821);
        Check_Close ("leftmost: readiness falls with position", By_Leftmost.Readiness (Board, Model, 5), 0.6);
        Check_Close ("agreement among the neurons of a brain", By_Agreement.Readiness (Board, Mixed_Brain, 5), 0.1481966929575596);
        Check_Close (
            "agreement without neurons to compare answers as certainty",
            By_Agreement.Readiness (Board, Model, 5),
            0.7760918157754821
            );
        Criteria.Add_Part (Mix, By_Certainty, 3.0);
        Criteria.Add_Part (Mix, By_Leftmost, 1.0);
        Check_Close ("a mix of criteria is their weighted mean", Mix.Readiness (Board, Model, 5), 0.7320688618316117);

        Collapsing.Collapse_By (Filled, Model, Dice, By_Certainty);
        Check ("collapse by certainty: no holes are left", Canvases.Blank_Count (Filled) = 0);
        Check_Mirror ("collapse by certainty is most-certain-first", Templates.Rendered (Filled, Letters, True), "la [costa. es la] rosa.");

        Filled := Templates.Parsed (Template, Letters);
        Dice := Random_Sources.Seeded (1);
        Collapsing.Collapse_By (Filled, Model, Dice, By_Leftmost, Collapsing.Always_Most_Likely);
        Check_Mirror ("collapse by leftmost is left to right", Templates.Rendered (Filled, Letters, True), "la [casa de la l] rosa.");

        Filled := Templates.Parsed (Template, Letters);
        Dice := Random_Sources.Seeded (1);
        Collapsing.Collapse_By (Filled, Mixed_Brain, Dice, By_Agreement);
        Check ("collapse by agreement: no holes are left", Canvases.Blank_Count (Filled) = 0);
        Check_Mirror ("collapse by agreement, seed 1", Templates.Rendered (Filled, Letters, True), "la [coco de roso] rosa.");
        end Test_Criteria;

    procedure Test_Sources is
        Reader        : Memory_Sources.Memory_Source;
        File_Reader   : File_Sources.File_Source;
        File_Letters  : Alphabets.Alphabet;
        Piece         : Texts.Symbol_Text;
        Found         : Boolean;
        Count         : Natural := 0;
        First_Matches : Boolean := False;
        begin
        Memory_Sources.Open (Reader, Corpus, 24, 7);
        Reader.Next_Piece (Piece, Found);
        Check (
            "memory source: the first piece of seed 7",
            Found and then Texts.Decoded (Piece, Letters) = " la cosa de la costa. el"
            );

        Texts.Learn_Alphabet (Sample_File, File_Letters);
        declare
            Whole : constant Texts.Symbol_Text := Texts.Read_Symbols (Sample_File, File_Letters);
            begin
            File_Sources.Open (File_Reader, Sample_File, File_Letters, 100);
            loop
                File_Reader.Next_Piece (Piece, Found);
                exit when not Found;
                Count := Count + 1;
                if Count = 1 then
                    First_Matches := (Piece = Texts.Part (Whole, 1, 100));
                    end if;
                end loop;
            File_Sources.Close (File_Reader);
            end;
        Check ("file source: 91 pieces of 100 letters", Count = 91);
        Check ("file source: the first piece is the start of the file", First_Matches);
        end Test_Sources;

    procedure Test_Records is
        Tape  : Records.Tape;
        Back  : Records.Tape;
        Packed : Records.Tape;
        Packed_Size : Natural;
        Row   : Numbers.Real_Row := Numbers.Zeros (4);
        Count : Natural;
        Real  : Long_Float;
        begin
        Row.Replace_Element (2, 2.5);
        Row.Replace_Element (4, -1.0);
        Records.Write_Word (Tape, "first");
        Records.Write_Count (Tape, 144);
        Records.Write_Real (Tape, -0.125);
        Records.Write_Reals (Tape, Row);
        Records.Save (Tape, Saved_Tape);
        Records.Load (Back, Saved_Tape);
        Ada.Directories.Delete_File (Saved_Tape);
        Check ("a word comes back from the file", Records.Read_Word (Back) = "first");
        Count := Records.Read_Count (Back);
        Check ("a whole number comes back", Count = 144);
        Real := Records.Read_Real (Back);
        Check ("a real number comes back exactly", Real = -0.125);
        Row := Records.Read_Reals (Back);
        Check (
            "a sparse row comes back with its zeros",
            Natural (Row.Length) = 4 and then Row.Element (1) = 0.0
            and then Row.Element (2) = 2.5 and then Row.Element (4) = -1.0
            );
        Records.Save (Tape, Packed_Tape);
        Records.Load (Packed, Packed_Tape);
        Packed_Size := Natural (Ada.Directories.Size (Packed_Tape));
        Ada.Directories.Delete_File (Packed_Tape);
        Check ("the packed form keeps the same word", Records.Read_Word (Packed) = "first");
        Count := Records.Read_Count (Packed);
        Real := Records.Read_Real (Packed);
        Row := Records.Read_Reals (Packed);
        Check (
            "the packed form keeps the same numbers",
            Count = 144 and then Real = -0.125 and then Natural (Row.Length) = 4
            and then Row.Element (2) = 2.5 and then Row.Element (4) = -1.0
            );
        Check ("the packed form of this tape takes 50 bytes", Packed_Size = 50);
        Check ("the package name of a brain file", Records.Unit_Name_For ("brains/page.brn") = "Page_Brain");
        Check ("marks in the file name become underlines", Records.Unit_Name_For ("my-page.2.brn") = "My_Page_2_Brain");
        end Test_Records;

    procedure Test_Web_Addresses is
        Base : constant String := "http://test.site/sub/c.html?x=1";
        begin
        Check ("a link one folder up", Web_Addresses.Resolved (Base, "../a.html") = "http://test.site/a.html");
        Check ("a link from the top of the site", Web_Addresses.Resolved (Base, "/index.html") = "http://test.site/index.html");
        Check ("the part after # is dropped", Web_Addresses.Resolved (Base, "d.html#top") = "http://test.site/sub/d.html");
        Check ("a link to the same page leads nowhere", Web_Addresses.Resolved (Base, "#top") = "");
        Check ("a mail link cannot be followed", Web_Addresses.Resolved (Base, "mailto:me@test.site") = "");
        Check ("a full address gets its final slash", Web_Addresses.Resolved (Base, "http://other.org") = "http://other.org/");
        Check ("a link that only changes the question", Web_Addresses.Resolved (Base, "?page=2") = "http://test.site/sub/c.html?page=2");
        Check ("stay-here and go-up parts are worked out", Web_Addresses.Resolved (Base, "./e/../f.html") = "http://test.site/sub/f.html");
        Check ("going up too far stops at the top", Web_Addresses.Resolved (Base, "../../..") = "http://test.site/");
        Check ("a link with a space is dropped", Web_Addresses.Resolved (Base, "a b.html") = "");
        Check ("the host of an address", Web_Addresses.Host_Of ("https://test.site:8080/a/b") = "test.site:8080");
        Check ("by name: no ending may be a page", Web_Addresses.Kind_By_Name ("http://test.site/wiki/Sea") = Web_Addresses.Page);
        Check ("by name: a picture, even in capitals", Web_Addresses.Kind_By_Name ("http://test.site/a.PNG?x=1.html") = Web_Addresses.Picture);
        Check ("by name: a film", Web_Addresses.Kind_By_Name ("http://test.site/clip.mp4") = Web_Addresses.Video);
        Check ("by name: program code is writing", Web_Addresses.Kind_By_Name ("http://test.site/tool.py") = Web_Addresses.Writing);
        Check ("by label: a page", Web_Addresses.Kind_By_Label ("Text/HTML; charset=utf-8") = Web_Addresses.Page);
        Check ("by label: a drawing written as text is writing", Web_Addresses.Kind_By_Label ("image/svg+xml") = Web_Addresses.Writing);
        Check ("by label: unknown bytes are other", Web_Addresses.Kind_By_Label ("application/octet-stream") = Web_Addresses.Other);
        Check ("the sense of program code is its ending", Web_Addresses.Sense_Of ("http://test.site/tool.py", Web_Addresses.Writing) = "py");
        Check ("the sense of a page is page", Web_Addresses.Sense_Of ("http://test.site/a.html", Web_Addresses.Page) = "page");
        end Test_Web_Addresses;

    Page_Markup : constant Wide_Wide_String :=
        "<html><head><title>Test &amp; page</title><style>p {color: red}</style>"
        & "<script>var a = '<p>not text</p>';</script></head><body><!-- a <b>comment</b> -->"
        & "<h1>Hello   world</h1><p>First <a href=""a.html?x=1&amp;y=2"">link</a> and "
        & "<A HREF='b.html'>another</A>&nbsp;one &#233; &bogus; AT&T.</p>"
        & "<img alt=""x"" src=""pic.png""><p>Second<br>third <video src=clip.mp4 controls></video> end</p>"
        & "<svg><circle/></svg>tail <a>no link</a> <a title=""href=x"" href = c.html >c</a>";

    function Block_Text (
            Content : in Pages.Page_Content;
            Index   : in Positive
            ) return Wide_Wide_String is
        begin
        return Wide_Texts.To_Wide_Wide_String (Content.Blocks.Element (Index).Text);
        end Block_Text;

    function Block_Kind_At (
            Content : in Pages.Page_Content;
            Index   : in Positive
            ) return Pages.Block_Kind is
        begin
        return Content.Blocks.Element (Index).Kind;
        end Block_Kind_At;

    procedure Test_Pages is
        Content  : constant Pages.Page_Content := Pages.Read (Wide_Texts.To_Unbounded_Wide_Wide_String (Page_Markup));
        E_Acute  : constant Wide_Wide_Character := Wide_Wide_Character'Val (233);
        Expected : constant Wide_Wide_String := "First link and another one " & E_Acute & " &bogus; AT&T.";
        begin
        Check ("the page is taken apart into 10 blocks", Natural (Content.Blocks.Length) = 10);
        Check ("the title is the first paragraph", Block_Kind_At (Content, 1) = Pages.Words and then Block_Text (Content, 1) = "Test & page");
        Check ("runs of spaces count as one", Block_Text (Content, 2) = "Hello world");
        Check ("letters written by name or number are read", Block_Text (Content, 3) = Expected);
        Check ("a picture keeps its place and its address", Block_Kind_At (Content, 4) = Pages.Picture and then Block_Text (Content, 4) = "pic.png");
        Check ("a line break starts a new paragraph", Block_Text (Content, 5) = "Second" and then Block_Text (Content, 6) = "third");
        Check ("a film keeps its place and its address", Block_Kind_At (Content, 7) = Pages.Video and then Block_Text (Content, 7) = "clip.mp4");
        Check ("a drawing inside the page keeps its place", Block_Kind_At (Content, 9) = Pages.Drawing);
        Check ("the last paragraph", Block_Text (Content, 10) = "tail no link c");
        Check (
            "three links, as written",
            Natural (Content.Links.Length) = 3 and then Content.Links.Element (1) = "a.html?x=1&y=2"
            and then Content.Links.Element (2) = "b.html" and then Content.Links.Element (3) = "c.html"
            );
        Check ("the words of the page, one paragraph per line", Wide_Texts.Length (Pages.Text_Of (Content)) = 99);
        end Test_Pages;

    Line_End : constant Wide_Wide_String := (1 => Wide_Wide_Character'Val (10));

    Rules_Text : constant Wide_Wide_String :=
        "# rules for the test" & Line_End
        & "User-agent: otherbot" & Line_End
        & "Disallow: /" & Line_End
        & Line_End
        & "User-agent: *" & Line_End
        & "Disallow: /private/" & Line_End
        & "Allow: /private/open/" & Line_End
        & "Disallow: /*.pdf$" & Line_End
        & "Disallow: /search?*q=" & Line_End
        & "Crawl-delay: 5" & Line_End
        & "Disallow:" & Line_End;

    Our_Rules_Text : constant Wide_Wide_String :=
        Rules_Text & "User-agent: calipso" & Line_End & "Disallow: /only-us/" & Line_End;

    procedure Test_Robots is
        Rules : constant Robots.Rule_Set := Robots.Parsed (Wide_Texts.To_Unbounded_Wide_Wide_String (Rules_Text), "Calipso");
        Named : constant Robots.Rule_Set := Robots.Parsed (Wide_Texts.To_Unbounded_Wide_Wide_String (Our_Rules_Text), "Calipso");
        begin
        Check ("the top of the site is allowed", Robots.Allows (Rules, "/"));
        Check ("a forbidden folder", not Robots.Allows (Rules, "/private/x"));
        Check ("the longest rule that fits decides", Robots.Allows (Rules, "/private/open/x"));
        Check ("a rule with * and $: ends in .pdf", not Robots.Allows (Rules, "/a/b.pdf"));
        Check ("a rule with $ does not fit a longer path", Robots.Allows (Rules, "/a/b.pdfx"));
        Check ("a rule with * in the middle", not Robots.Allows (Rules, "/search?a=1&q=2"));
        Check ("the same rule, when the end is missing", Robots.Allows (Rules, "/search?a=1"));
        Check ("the site asks for 5 seconds between requests", Robots.Delay_Of (Rules) = 5.0);
        Check (
            "rules that name us replace the rules for everybody",
            Robots.Allows (Named, "/private/x") and then not Robots.Allows (Named, "/only-us/x")
            );
        Check ("no rules at all: everything is allowed", Robots.Allows (Robots.Allow_Everything, "/x"));
        Check ("rules that could not be read: nothing is allowed", not Robots.Allows (Robots.Allow_Nothing, "/x"));
        end Test_Robots;

    procedure Test_Web_Sources is
        Common     : constant Alphabets.Alphabet := Alphabets.Common_Letters;
        Options    : Web_Sources.Settings;
        Site       : Folder_Fetchers.Folder_Fetcher;
        Reader     : Web_Sources.Web_Source;
        Piece      : Texts.Symbol_Text;
        Found      : Boolean;
        Count      : Natural := 0;
        Good_Start : Boolean := False;
        Counts     : Web_Sources.Tally;
        Opening    : constant Wide_Wide_String :=
            "The little test site" & Line_End & "The little test site" & Line_End & "This site is small";
        begin
        Check ("the common alphabet has 144 symbols", Alphabets.Size (Common) = 144);
        Options.Pause := 0.0;
        Folder_Fetchers.Prepare (Site, Test_Site, Site_Folder);
        Web_Sources.Open (Reader, Site, Common, Options, Page_Work_File);
        Web_Sources.Add_Address (Reader, Test_Site & "/index.html");
        loop
            Reader.Next_Piece (Piece, Found);
            exit when not Found;
            Count := Count + 1;
            if Count = 1 then
                Good_Start := Texts.Decoded (Piece, Common) (1 .. Opening'Length) = Opening;
                end if;
            end loop;
        Ada.Directories.Delete_File (Page_Work_File);
        Counts := Web_Sources.Tally_Of (Reader);
        Check ("the site gives 17 pieces of 64 letters", Count = 17);
        Check ("the first piece starts with the title", Good_Start);
        Check ("5 pages asked for, 4 read, 1113 letters", Counts.Asked = 5 and then Counts.Read = 4 and then Counts.Letters = 1_113);
        Check ("the private page is refused by the site's rules", Counts.Refused = 1);
        Check (
            "the file with no ending is asked for, and is not text",
            Counts.Not_Text = 1 and then Web_Sources.Find_Count (Reader, Web_Addresses.Other) = 1
            );
        Check ("nothing failed", Counts.Failed = 0);
        Check (
            "files that are not pages are filed by kind, never asked for",
            Web_Sources.Find_Count (Reader, Web_Addresses.Writing) = 2
            and then Web_Sources.Find_Count (Reader, Web_Addresses.Picture) = 1
            and then Web_Sources.Find_Count (Reader, Web_Addresses.Video) = 1
            and then Web_Sources.Find_Count (Reader, Web_Addresses.Sound) = 1
            );
        Check (
            "a page linked again is not listed again: it gets mentions",
            Web_Sources.Mentions_Of (Reader, Test_Site & "/index.html") = 4
            );
        Check ("the other site was never listed", Web_Sources.Mentions_Of (Reader, "http://elsewhere.example/") = 0);

        Options.List_Size := 2;
        Web_Sources.Open (Reader, Site, Common, Options, Page_Work_File);
        Web_Sources.Add_Address (Reader, Test_Site & "/index.html");
        loop
            Reader.Next_Piece (Piece, Found);
            exit when not Found;
            end loop;
        Ada.Directories.Delete_File (Page_Work_File);
        Counts := Web_Sources.Tally_Of (Reader);
        Check ("a waiting list of 2: the 4 pages are still read", Counts.Asked = 4 and then Counts.Read = 4);
        Check (
            "a waiting list of 2: 3 links are left out",
            Counts.Left_Out = 3 and then Web_Sources.Waiting_Count (Reader) = 0
            );
        end Test_Web_Sources;

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
    Run_Group ("Bounded memory", Test_Bounded_Memory'Access);
    Run_Group ("Neurons that measure distance", Test_Basis_Neurons'Access);
    Run_Group ("Brain files", Test_Records'Access);
    Run_Group ("Brains", Test_Brains'Access);
    Run_Group ("Criteria", Test_Criteria'Access);
    Run_Group ("Sources", Test_Sources'Access);
    Run_Group ("Web addresses", Test_Web_Addresses'Access);
    Run_Group ("Pages", Test_Pages'Access);
    Run_Group ("Site rules", Test_Robots'Access);
    Run_Group ("Web source", Test_Web_Sources'Access);
    Console.Put_Line ("");
    Console.Put_Line ("Failures: " & Console.Image (Failures) & "   Notes: " & Console.Image (Warnings));
    if Failures > 0 then
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
        end if;
    end Calipso_Tests;
