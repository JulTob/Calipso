with Ada.Strings.Unbounded;

with Calipso.Neuron_Kinds;
with Calipso.Templates;

package body Calipso.Brains is

    File_Mark        : constant String := "calipso-brain";
    File_Version     : constant Natural := 1;
    Recipe_Separator : constant Character := '+';

    function Scores_At (
            Self     : in Brain;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Score_Array is
        Scores : Distributions.Score_Array (1 .. Alphabets.Size (Self.Alphabet)) := (others => 0.0);
        begin
        for Index in 1 .. Neuron_Count (Self) loop
            Self.Cells (Index).Add_Scores (Board, Position, Self.Weights.Element (Index), Scores);
            end loop;
        return Scores;
        end Scores_At;
    --# The points of the whole brain for each candidate letter.

    procedure Prepare (
            Self    : in out Brain;
            Letters : in     Alphabets.Alphabet
            ) is
        begin
        Self.Alphabet := Letters;
        Self.Cells.Clear;
        Self.Weights.Clear;
        Self.Studied := 0;
        Self.Learning_Rate := Default_Learning_Rate;
        end Prepare;

    procedure Add_Neuron (
            Self   : in out Brain;
            Item   : in     Neurons.Neuron'Class;
            Weight : in     Long_Float := 1.0
            ) is
        begin
        Self.Cells.Append (Item);
        Self.Weights.Append (Weight);
        end Add_Neuron;

    procedure Add_By_Name (
            Self : in out Brain;
            Name : in     String
            ) is
        Item : constant Neurons.Neuron'Class := Neuron_Kinds.Made (Name, Alphabets.Size (Self.Alphabet));
        begin
        Add_Neuron (Self, Item);
        end Add_By_Name;

    procedure Add_Recipe (
            Self   : in out Brain;
            Recipe : in     String
            ) is
        First : Positive := Recipe'First;
        begin
        for Index in Recipe'Range loop
            if Recipe (Index) = Recipe_Separator then
                Add_By_Name (Self, Recipe (First .. Index - 1));
                First := Index + 1;
                end if;
            end loop;
        Add_By_Name (Self, Recipe (First .. Recipe'Last));
        end Add_Recipe;

    function Neuron_Count (
            Self : in Brain
            ) return Natural is
        begin
        return Natural (Self.Cells.Length);
        end Neuron_Count;

    function Recipe_Of (
            Self : in Brain
            ) return String is
        use Ada.Strings.Unbounded;
        Recipe : Unbounded_String;
        begin
        for Index in 1 .. Neuron_Count (Self) loop
            if Index > 1 then
                Append (Recipe, Recipe_Separator);
                end if;
            Append (Recipe, Self.Cells (Index).Name);
            end loop;
        return To_String (Recipe);
        end Recipe_Of;

    function Lessons_Studied (
            Self : in Brain
            ) return Natural is
        begin
        return Self.Studied;
        end Lessons_Studied;

    function Letters_Of (
            Self : in Brain
            ) return Alphabets.Alphabet is
        begin
        return Self.Alphabet;
        end Letters_Of;

    function Neuron_Reach (
            Self  : in Brain;
            Index : in Positive
            ) return Natural is
        begin
        return Self.Cells (Index).Reach;
        end Neuron_Reach;

    function Neuron_Opinion (
            Self     : in Brain;
            Index    : in Positive;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution is
        Scores : Distributions.Score_Array (1 .. Alphabets.Size (Self.Alphabet)) := (others => 0.0);
        begin
        Self.Cells (Index).Add_Scores (Board, Position, 1.0, Scores);
        return Distributions.From_Scores (Scores);
        end Neuron_Opinion;

    procedure Learn_Cell (
            Self     : in out Brain;
            Board    : in     Canvases.Canvas;
            Position : in     Positive;
            Actual   : in     Symbol;
            Result   : in out Blind_Spots.Exam_Result
            ) is
        Belief : constant Distributions.Distribution := Opinion (Self, Board, Position);
        Errors : Distributions.Score_Array (1 .. Alphabets.Size (Self.Alphabet));
        Step   : constant Long_Float := Self.Learning_Rate / Long_Float (Neuron_Count (Self));
        --# The correction is shared equally among the neurons.
        begin
        Result.Hidden := Result.Hidden + 1;
        Result.Surprise_Sum := Result.Surprise_Sum + Distributions.Surprise_Of (Belief, Actual);
        if Distributions.Most_Likely (Belief) = Actual then
            Result.Hits := Result.Hits + 1;
            end if;
        for Candidate in Errors'Range loop
            Errors (Candidate) := Distributions.Probability_Of (Belief, Candidate);
            --# Each letter loses what was bet on it...
            end loop;
        Errors (Actual) := Errors (Actual) - 1.0;
        --# ...and the real letter gets what it was missing to reach 1.
        for Index in 1 .. Neuron_Count (Self) loop
            Self.Cells (Index).Learn_From_Cell (Board, Position, Errors, Step * Self.Weights.Element (Index));
            end loop;
        end Learn_Cell;

    procedure Study_Piece (
            Self   : in out Brain;
            Piece  : in     Texts.Symbol_Text;
            Dice   : in out Random_Sources.Generator;
            Result : in out Blind_Spots.Exam_Result
            ) is
        Length   : constant Natural := Natural (Piece.Length);
        Original : constant Canvases.Canvas := Templates.From_Text (Piece, 1, Length);
        Board    : Canvases.Canvas := Original;
        Rate     : Random_Sources.Unit_Fraction;
        Actual   : Symbol;
        begin
        Random_Sources.Draw_Unit (Dice, Rate);
        --# Each lesson hides a different amount: sometimes almost nothing, sometimes almost everything.
        Blind_Spots.Hide_At_Random (Board, Rate, Dice);
        for Position in 1 .. Length loop
            if Canvases.Is_Blank (Board, Position) then
                Actual := Canvases.Symbol_At (Original, Position);
                Learn_Cell (Self, Board, Position, Actual, Result);
                end if;
            end loop;
        for Index in 1 .. Neuron_Count (Self) loop
            Self.Cells (Index).Learn_From_Text (Piece);
            end loop;
        Self.Studied := Self.Studied + 1;
        end Study_Piece;

    procedure Study (
            Self    : in out Brain;
            From    : in out Sources.Source'Class;
            Dice    : in out Random_Sources.Generator;
            Lessons : in     Natural;
            Result  :    out Blind_Spots.Exam_Result
            ) is
        Piece : Texts.Symbol_Text;
        Found : Boolean;
        begin
        Result := (others => <>);
        for Lesson in 1 .. Lessons loop
            From.Next_Piece (Piece, Found);
            exit when not Found;
            Study_Piece (Self, Piece, Dice, Result);
            end loop;
        end Study;

    procedure Write_Brain (
            Self : in     Brain;
            Tape : in out Records.Tape
            ) is
        Size : constant Symbol := Alphabets.Size (Self.Alphabet);
        Char : Wide_Wide_Character;
        begin
        Records.Write_Word (Tape, File_Mark);
        Records.Write_Count (Tape, File_Version);
        Records.Write_Count (Tape, Natural (Size));
        for Value in Symbol range 1 .. Size loop
            Char := Alphabets.Character_Of (Self.Alphabet, Value);
            Records.Write_Count (Tape, Wide_Wide_Character'Pos (Char));
            --# Each letter is saved as its Unicode number.
            end loop;
        Records.Write_Count (Tape, Self.Studied);
        Records.Write_Real (Tape, Self.Learning_Rate);
        Records.Write_Count (Tape, Neuron_Count (Self));
        for Index in 1 .. Neuron_Count (Self) loop
            Records.Write_Word (Tape, Self.Cells (Index).Kind);
            Records.Write_Real (Tape, Self.Weights.Element (Index));
            Self.Cells (Index).Save (Tape);
            end loop;
        end Write_Brain;

    procedure Save (
            Self      : in Brain;
            File_Name : in String
            ) is
        Tape : Records.Tape;
        begin
        Write_Brain (Self, Tape);
        Records.Save (Tape, File_Name);
        end Save;

    procedure Read_Alphabet (
            Letters : in out Alphabets.Alphabet;
            Tape    : in out Records.Tape
            ) is
        Size   : constant Natural := Records.Read_Count (Tape);
        Number : Natural;
        begin
        for Value in 1 .. Size loop
            Number := Records.Read_Count (Tape);
            if Value > 1 then
                Alphabets.Include (Letters, Wide_Wide_Character'Val (Number));
                end if;
            --# Symbol 1 is always the unknown mark: its number is read and set aside.
            end loop;
        end Read_Alphabet;

    procedure Read_Neuron (
            Self : in out Brain;
            Tape : in out Records.Tape
            ) is
        Kind   : constant String := Records.Read_Word (Tape);
        Weight : constant Long_Float := Records.Read_Real (Tape);
        Item   : Neurons.Neuron'Class := Neuron_Kinds.Blank_Of_Kind (Kind);
        begin
        Item.Load (Tape);
        Add_Neuron (Self, Item, Weight);
        end Read_Neuron;

    procedure Read_Brain (
            Self : in out Brain;
            Tape : in out Records.Tape
            ) is
        Letters : Alphabets.Alphabet;
        Version : Natural;
        Count   : Natural;
        begin
        Records.Expect_Word (Tape, File_Mark);
        Version := Records.Read_Count (Tape);
        if Version /= File_Version then
            raise Records.Record_Error with "this brain was saved by a different version";
            end if;
        Read_Alphabet (Letters, Tape);
        Prepare (Self, Letters);
        Self.Studied := Records.Read_Count (Tape);
        Self.Learning_Rate := Records.Read_Real (Tape);
        Count := Records.Read_Count (Tape);
        for Index in 1 .. Count loop
            Read_Neuron (Self, Tape);
            end loop;
        end Read_Brain;

    procedure Load (
            Self      : in out Brain;
            File_Name : in     String
            ) is
        Tape : Records.Tape;
        begin
        Records.Load (Tape, File_Name);
        Read_Brain (Self, Tape);
        end Load;

    procedure Thaw (
            Self    : in out Brain;
            Words   : in     Records.Word_List;
            Figures : in     Records.Number_List
            ) is
        Tape : Records.Tape;
        begin
        Records.Fill (Tape, Words, Figures);
        Read_Brain (Self, Tape);
        end Thaw;

    overriding function Alphabet_Size (
            Self : in Brain
            ) return Symbol is
        begin
        return Alphabets.Size (Self.Alphabet);
        end Alphabet_Size;

    overriding function Reach (
            Self : in Brain
            ) return Natural is
        Widest : Natural := 0;
        begin
        for Index in 1 .. Neuron_Count (Self) loop
            if Neuron_Reach (Self, Index) > Widest then
                Widest := Neuron_Reach (Self, Index);
                end if;
            end loop;
        return Widest;
        end Reach;

    overriding function Opinion (
            Self     : in Brain;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution is
        Scores : constant Distributions.Score_Array := Scores_At (Self, Board, Position);
        begin
        return Distributions.From_Scores (Scores);
        end Opinion;

    end Calipso.Brains;
