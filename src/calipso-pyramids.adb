with Ada.Strings.Wide_Wide_Fixed;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Wide_Wide_Characters.Handling;

with Calipso.Boxed_Oracles;
with Calipso.Collapsing;
with Calipso.Tokens;

package body Calipso.Pyramids is

    use Ada.Strings.Wide_Wide_Unbounded;
    use type Kinds.Kind_Family;

    Stop_Mark       : constant Wide_Wide_String := ".";
    Opening_Marks   : constant Wide_Wide_String := "([";
    Glue_Marks      : constant Wide_Wide_String := "-'";
    Space           : constant Wide_Wide_String := " ";
    Fallback_Length : constant Positive := 4;
    --# The size of the box of a kind no word was ever seen in.

    type Last_Put is (At_Start, After_Opening, After_Glue, After_Break, After_Mark, After_Word);

    function Kind_Text (
            Book   : in Kinds.Book;
            Sample : in Tokens.Token_List
            ) return Texts.Symbol_Text is
        Result : Texts.Symbol_Text;
        begin
        for Token of Sample loop
            Result.Append (Kinds.Kind_Of (Book, Token));
            end loop;
        return Result;
        end Kind_Text;
    --# The text as the level of kinds sees it: one kind for each token.

    procedure Study (
            Self : in out Pyramid;
            Text : in     Wide_Wide_String
            ) is
        Plain : constant Kind_Makers.Settings := (others => <>);
        begin
        Study (Self, Text, Plain);
        end Study;

    procedure Study (
            Self    : in out Pyramid;
            Text    : in     Wide_Wide_String;
            Options : in     Kind_Makers.Settings
            ) is
        Sample : constant Tokens.Token_List := Tokens.Split (Text);
        begin
        Self.Book := Kind_Makers.Book_Of (Sample, Options);
        Counting_Oracles.Train (Self.Brain, Kind_Text (Self.Book, Sample), Kinds.Kind_Count (Self.Book), Default_Longest);
        end Study;

    function Kind_Opinion (
            Self     : in Pyramid;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution is
        begin
        return Self.Brain.Opinion (Board, Position);
        end Kind_Opinion;

    function Book_Of (
            Self : in Pyramid
            ) return Kinds.Book is
        begin
        return Self.Book;
        end Book_Of;

    function Blank_Plan (
            Self : in Pyramid;
            Size : in Positive
            ) return Canvases.Canvas is
        Stop : constant Symbol := Kinds.Kind_Of (Self.Book, Stop_Mark);
        Plan : Canvases.Canvas;
        begin
        if Stop /= Unknown then
            Canvases.Append_Given (Plan, Stop);
            end if;
        for Count in 1 .. Size loop
            Canvases.Append_Blank (Plan);
            end loop;
        if Stop /= Unknown then
            Canvases.Append_Given (Plan, Stop);
            end if;
        return Plan;
        end Blank_Plan;
    --# Size kinds to decide, between two full stops when the text has them.

    type Letter_Rules is record
        Small   : Boxed_Oracles.Cell_Rule;
        Capital : Boxed_Oracles.Cell_Rule;
        Figure  : Boxed_Oracles.Cell_Rule;
        end record;
    --# The three permissions a box uses, worked out once from the alphabet.

    function Is_Small_Letter (
            Char : in Wide_Wide_Character
            ) return Boolean is
        begin
        return Tokens.Is_Letter (Char) and then not Ada.Wide_Wide_Characters.Handling.Is_Upper (Char);
        end Is_Small_Letter;

    function Is_Capital_Letter (
            Char : in Wide_Wide_Character
            ) return Boolean is
        begin
        return Ada.Wide_Wide_Characters.Handling.Is_Upper (Char);
        end Is_Capital_Letter;

    function Rule_For (
            Letters : in Alphabets.Alphabet;
            Belongs : not null access function (Char : in Wide_Wide_Character) return Boolean
            ) return Boxed_Oracles.Cell_Rule is
        Allowed : Boxed_Oracles.Permission := (others => False);
        begin
        for Value in 2 .. Alphabets.Size (Letters) loop
            Allowed (Value) := Belongs (Alphabets.Character_Of (Letters, Value));
            end loop;
        return Boxed_Oracles.Rule_Of (Allowed);
        end Rule_For;
    --# The rule "only the letters of the alphabet that pass this test".

    function Rules_Of (
            Letters : in Alphabets.Alphabet
            ) return Letter_Rules is
        Rules : Letter_Rules;
        begin
        Rules.Small := Rule_For (Letters, Is_Small_Letter'Access);
        Rules.Capital := Rule_For (Letters, Is_Capital_Letter'Access);
        Rules.Figure := Rule_For (Letters, Tokens.Is_Digit'Access);
        return Rules;
        end Rules_Of;

    type Draft is record
        Board : Canvases.Canvas;
        Rules : Boxed_Oracles.Rule_List;
        Last  : Last_Put := At_Start;
        end record;
    --# A canvas of letters being prepared: the cells, the rule of each cell, and what was put last.

    procedure Put_Given (
            Sheet   : in out Draft;
            Letters : in     Alphabets.Alphabet;
            Plain   : in     Wide_Wide_String
            ) is
        begin
        for Char of Plain loop
            Canvases.Append_Given (Sheet.Board, Alphabets.Symbol_Of (Letters, Char));
            Sheet.Rules.Append (Boxed_Oracles.Free_Rule);
            end loop;
        end Put_Given;

    procedure Put_Hole (
            Sheet : in out Draft;
            Rule  : in     Boxed_Oracles.Cell_Rule
            ) is
        begin
        Canvases.Append_Blank (Sheet.Board);
        Sheet.Rules.Append (Rule);
        end Put_Hole;

    procedure Put_Space_If_Needed (
            Sheet   : in out Draft;
            Letters : in     Alphabets.Alphabet
            ) is
        begin
        if Sheet.Last = After_Mark or else Sheet.Last = After_Word then
            Put_Given (Sheet, Letters, Space);
            end if;
        end Put_Space_If_Needed;
    --# A word is set apart from what came before, except at the start, after "(" and after "-".

    function Is_One_Of (
            Mark  : in Wide_Wide_String;
            Marks : in Wide_Wide_String
            ) return Boolean is
        begin
        return Ada.Strings.Wide_Wide_Fixed.Index (Marks, Mark) > 0;
        end Is_One_Of;

    procedure Put_Mark (
            Sheet   : in out Draft;
            Letters : in     Alphabets.Alphabet;
            Mark    : in     Wide_Wide_String
            ) is
        begin
        if Mark = Tokens.Break_Text then
            Put_Given (Sheet, Letters, Mark);
            Sheet.Last := After_Break;
        elsif Is_One_Of (Mark, Opening_Marks) then
            Put_Space_If_Needed (Sheet, Letters);
            Put_Given (Sheet, Letters, Mark);
            Sheet.Last := After_Opening;
        elsif Is_One_Of (Mark, Glue_Marks) then
            Put_Given (Sheet, Letters, Mark);
            Sheet.Last := After_Glue;
        else
            Put_Given (Sheet, Letters, Mark);
            Sheet.Last := After_Mark;
            end if;
        end Put_Mark;

    procedure Put_Number (
            Sheet   : in out Draft;
            Rules   : in     Letter_Rules;
            Figures : in     Natural
            ) is
        begin
        for Count in 1 .. Figures loop
            Put_Hole (Sheet, Rules.Figure);
            end loop;
        end Put_Number;

    procedure Put_Box (
            Sheet   : in out Draft;
            Letters : in     Alphabets.Alphabet;
            Rules   : in     Letter_Rules;
            Length  : in     Natural;
            Capital : in     Boolean;
            Ending  : in     Wide_Wide_String
            ) is
        begin
        for Index in 1 .. Length - Ending'Length loop
            if Index = 1 and then Capital then
                Put_Hole (Sheet, Rules.Capital);
            else
                Put_Hole (Sheet, Rules.Small);
                end if;
            end loop;
        Put_Given (Sheet, Letters, Ending);
        end Put_Box;
    --# Holes for the letters the brain will write, then the ending of the kind.

    procedure Put_Shape (
            Sheet   : in out Draft;
            Book    : in     Kinds.Book;
            Letters : in     Alphabets.Alphabet;
            Rules   : in     Letter_Rules;
            Dice    : in out Random_Sources.Generator;
            Passing : in     Handover;
            Kind    : in     Symbol
            ) is
        Capital : constant Boolean := Kinds.Is_Capital (Book, Kind);
        Ending  : constant Wide_Wide_String := Kinds.Text_Of (Book, Kind);
        Member  : Texts.Wide_Text;
        begin
        if not Kinds.Has_Members (Book, Kind) then
            Put_Box (Sheet, Letters, Rules, Fallback_Length, Capital, Ending);
            return;
            end if;
        Kinds.Draw_Member (Book, Kind, Dice, Member);
        if Passing = Pick then
            Put_Given (Sheet, Letters, To_Wide_Wide_String (Member));
        else
            Put_Box (Sheet, Letters, Rules, Ada.Strings.Wide_Wide_Unbounded.Length (Member), Capital, Ending);
            --# Of the word drawn, only the length is kept: the letters are the brain's to choose.
            end if;
        end Put_Shape;

    procedure Put_Kind (
            Sheet   : in out Draft;
            Book    : in     Kinds.Book;
            Letters : in     Alphabets.Alphabet;
            Rules   : in     Letter_Rules;
            Dice    : in out Random_Sources.Generator;
            Passing : in     Handover;
            Kind    : in     Symbol
            ) is
        Family : constant Kinds.Kind_Family := Kinds.Family_Of (Book, Kind);
        begin
        if Family = Kinds.Unknown_Kind then
            return;
            end if;
        if Family = Kinds.Mark_Kind then
            Put_Mark (Sheet, Letters, Kinds.Text_Of (Book, Kind));
            return;
            end if;
        Put_Space_If_Needed (Sheet, Letters);
        if Family = Kinds.Word_Kind then
            Put_Given (Sheet, Letters, Kinds.Text_Of (Book, Kind));
        elsif Family = Kinds.Number_Kind then
            Put_Number (Sheet, Rules, Kinds.Figures_Of (Book, Kind));
        else
            Put_Shape (Sheet, Book, Letters, Rules, Dice, Passing, Kind);
            end if;
        Sheet.Last := After_Word;
        end Put_Kind;

    procedure Fill_Draft (
            Sheet   : in out Draft;
            Self    : in     Pyramid;
            Plan    : in     Canvases.Canvas;
            Letters : in     Alphabets.Alphabet;
            Dice    : in out Random_Sources.Generator;
            Passing : in     Handover
            ) is
        Rules : constant Letter_Rules := Rules_Of (Letters);
        First : Positive := 1;
        begin
        if Kinds.Kind_Of (Self.Book, Stop_Mark) /= Unknown then
            First := 2;
            --# The opening full stop only gave the plan a start: it is not written.
            end if;
        for Position in First .. Canvases.Length (Plan) loop
            Put_Kind (Sheet, Self.Book, Letters, Rules, Dice, Passing, Canvases.Symbol_At (Plan, Position));
            end loop;
        end Fill_Draft;
    --# The handover: every kind of the plan becomes given letters or a box of holes.

    procedure Fill_Boxes (
            Sheet   : in out Draft;
            Speller : in     Oracles.Oracle'Class;
            Dice    : in out Random_Sources.Generator
            ) is
        Boxed : Boxed_Oracles.Boxed_Oracle (Speller'Access);
        begin
        Boxed.Rules := Sheet.Rules;
        Collapsing.Collapse_All (Sheet.Board, Boxed, Dice);
        end Fill_Boxes;
    --# The level of letters: the same collapse as always, with a brain that obeys the rules of each cell.

    function Plain_Text (
            Board   : in Canvases.Canvas;
            Letters : in Alphabets.Alphabet
            ) return Wide_Wide_String is
        Plain : Wide_Wide_String (1 .. Canvases.Length (Board));
        begin
        for Position in Plain'Range loop
            Plain (Position) := Alphabets.Character_Of (Letters, Canvases.Symbol_At (Board, Position));
            end loop;
        return Plain;
        end Plain_Text;

    procedure Write (
            Self    : in     Pyramid;
            Speller : in     Oracles.Oracle'Class;
            Letters : in     Alphabets.Alphabet;
            Dice    : in out Random_Sources.Generator;
            Size    : in     Positive;
            Passing : in     Handover;
            Result  :    out Texts.Wide_Text
            ) is
        Plan  : Canvases.Canvas := Blank_Plan (Self, Size);
        Sheet : Draft;
        begin
        Collapsing.Collapse_All (Plan, Self.Brain, Dice);
        Fill_Draft (Sheet, Self, Plan, Letters, Dice, Passing);
        Fill_Boxes (Sheet, Speller, Dice);
        Result := To_Unbounded_Wide_Wide_String (Plain_Text (Sheet.Board, Letters));
        end Write;

    end Calipso.Pyramids;
