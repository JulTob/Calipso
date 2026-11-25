with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Wide_Wide_Characters.Handling;

package body Calipso.Kinds is

    use Ada.Strings.Wide_Wide_Unbounded;
    use type Tokens.Token_Sort;

    type Tally is record
        Text  : Texts.Wide_Text;
        Seen  : Natural := 0;
        First : Positive := 1;
        --# Its place in order of first appearance: it breaks ties when ranking.
        end record;

    function Is_Before (
            Left  : in Tally;
            Right : in Tally
            ) return Boolean is
        begin
        if Left.Seen /= Right.Seen then
            return Left.Seen > Right.Seen;
            end if;
        return Left.First < Right.First;
        end Is_Before;
    --# The most seen first. On a tie, the one that appeared first.

    package Tally_Vectors is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Tally
            );

    package Tally_Sorting is new Tally_Vectors.Generic_Sorting ("<" => Is_Before);

    type Tally_List is record
        Items    : Tally_Vectors.Vector;
        Place_Of : Place_Maps.Map;
        end record;
    --# How many times each text was seen, kept in order of first appearance.

    procedure Add_Amount (
            Counts : in out Tally_List;
            Text   : in     Wide_Wide_String;
            Amount : in     Positive
            ) is
        Place   : Positive;
        Counted : Tally;
        begin
        if not Counts.Place_Of.Contains (Text) then
            Counted.Text := To_Unbounded_Wide_Wide_String (Text);
            Counted.First := Natural (Counts.Items.Length) + 1;
            Counts.Items.Append (Counted);
            Counts.Place_Of.Insert (Text, Counted.First);
            end if;
        Place := Counts.Place_Of.Element (Text);
        Counted := Counts.Items.Element (Place);
        Counted.Seen := Counted.Seen + Amount;
        Counts.Items.Replace_Element (Place, Counted);
        end Add_Amount;

    function Ranked (
            Counts : in Tally_List
            ) return Tally_Vectors.Vector is
        Ranking : Tally_Vectors.Vector := Counts.Items;
        begin
        Tally_Sorting.Sort (Ranking);
        return Ranking;
        end Ranked;

    function Word_Tallies (
            Sample : in Tokens.Token_List
            ) return Tally_List is
        Counts : Tally_List;
        begin
        for Token of Sample loop
            if Tokens.Sort_Of (Token) = Tokens.Word then
                Add_Amount (Counts, Token, 1);
                end if;
            end loop;
        return Counts;
        end Word_Tallies;

    function Kind_Count (
            Self : in Book
            ) return Symbol is
        begin
        return Self.Used;
        end Kind_Count;

    procedure New_Kind (
            Self : in out Book;
            Note : in     Kind_Note
            )
        with Pre => Self.Used < Symbol'Last;

    procedure New_Kind (
            Self : in out Book;
            Note : in     Kind_Note
            ) is
        begin
        Self.Used := Self.Used + 1;
        Self.Notes (Self.Used) := Note;
        end New_Kind;
    --# The new kind is number Self.Used.

    function Is_Sign (
            Token : in Wide_Wide_String
            ) return Boolean is
        Sort : constant Tokens.Token_Sort := Tokens.Sort_Of (Token);
        begin
        return Sort = Tokens.Mark or else Sort = Tokens.Break;
        end Is_Sign;

    procedure Note_Marks (
            Self   : in out Book;
            Sample : in     Tokens.Token_List
            ) is
        Taken : Natural := 0;
        Note  : Kind_Note;
        begin
        for Token of Sample loop
            if Is_Sign (Token) and then not Self.By_Text.Contains (Token) and then Taken < Most_Marks then
                Note.Family := Mark_Kind;
                Note.Text := To_Unbounded_Wide_Wide_String (Token);
                New_Kind (Self, Note);
                Self.By_Text.Insert (Token, Self.Used);
                Taken := Taken + 1;
                end if;
            end loop;
        end Note_Marks;
    --# Every mark is its own kind, in order of appearance, while there is room.

    procedure Note_Numbers (
            Self : in out Book
            ) is
        Note : Kind_Note;
        begin
        Self.First_Number := Self.Used + 1;
        for Figures in 1 .. Number_Kinds loop
            Note.Family := Number_Kind;
            Note.Figures := Figures;
            New_Kind (Self, Note);
            end loop;
        end Note_Numbers;

    procedure Note_Words (
            Self    : in out Book;
            Ranking : in     Tally_Vectors.Vector
            ) is
        Limit : constant Natural := Natural'Min (Most_Words, Natural (Ranking.Length));
        Note  : Kind_Note;
        begin
        for Place in 1 .. Limit loop
            Note.Family := Word_Kind;
            Note.Text := Ranking.Element (Place).Text;
            New_Kind (Self, Note);
            Self.By_Text.Insert (To_Wide_Wide_String (Note.Text), Self.Used);
            end loop;
        end Note_Words;
    --# The most usual words are their own kind.

    function Has_Ending (
            Word : in Wide_Wide_String
            ) return Boolean is
        begin
        return Word'Length >= Shortest_With_Ending;
        end Has_Ending;

    function Ending_Of_Word (
            Word : in Wide_Wide_String
            ) return Wide_Wide_String is
        begin
        return Ada.Wide_Wide_Characters.Handling.To_Lower (Word (Word'Last - Ending_Length + 1 .. Word'Last));
        end Ending_Of_Word;

    procedure Keep_Top_Endings (
            Self    : in out Book;
            Ranking : in     Tally_Vectors.Vector
            ) is
        Limit : constant Natural := Natural'Min (Most_Endings, Natural (Ranking.Length));
        begin
        for Place in 1 .. Limit loop
            Self.Ending_Place.Insert (To_Wide_Wide_String (Ranking.Element (Place).Text), Place);
            end loop;
        end Keep_Top_Endings;

    procedure Note_Endings (
            Self  : in out Book;
            Words : in     Tally_List
            ) is
        Counts : Tally_List;
        begin
        for Counted of Words.Items loop
            declare
                Word : constant Wide_Wide_String := To_Wide_Wide_String (Counted.Text);
                begin
                if not Self.By_Text.Contains (Word) and then Has_Ending (Word) then
                    Add_Amount (Counts, Ending_Of_Word (Word), Counted.Seen);
                    end if;
                end;
            end loop;
        Keep_Top_Endings (Self, Ranked (Counts));
        end Note_Endings;
    --# The most usual endings among the words that are not their own kind.

    procedure Note_Shapes (
            Self : in out Book
            ) is
        Count   : constant Natural := Natural (Self.Ending_Place.Length);
        Endings : array (0 .. Most_Endings) of Texts.Wide_Text;
        Note    : Kind_Note;
        begin
        for Position in Self.Ending_Place.Iterate loop
            Endings (Place_Maps.Element (Position)) := To_Unbounded_Wide_Wide_String (Place_Maps.Key (Position));
            end loop;
        Self.First_Shape := Self.Used + 1;
        for Capital in Boolean loop
            for Group in 0 .. Size_Groups - 1 loop
                for Place in 0 .. Count loop
                    Note.Family := Shape_Kind;
                    Note.Capital := Capital;
                    Note.Group := Group;
                    Note.Text := Endings (Place);
                    New_Kind (Self, Note);
                    end loop;
                end loop;
            end loop;
        end Note_Shapes;
    --# One kind for every mix of capital, size and ending. Ending 0 means "none of the usual ones".

    procedure Note_Members (
            Self  : in out Book;
            Words : in     Tally_List
            ) is
        Kind : Symbol;
        begin
        for Counted of Words.Items loop
            declare
                Word : constant Wide_Wide_String := To_Wide_Wide_String (Counted.Text);
                begin
                if not Self.By_Text.Contains (Word) then
                    Kind := Kind_Of (Self, Word);
                    Self.Members (Kind).Append (Kind_Member'(Word => Counted.Text, Seen => Counted.Seen));
                    Self.Totals (Kind) := Self.Totals (Kind) + Counted.Seen;
                    end if;
                end;
            end loop;
        end Note_Members;
    --# Which words were seen in each shape, and how often.

    function Built (
            Sample : in Tokens.Token_List
            ) return Book is
        Self  : Book;
        Words : constant Tally_List := Word_Tallies (Sample);
        begin
        Note_Marks (Self, Sample);
        Note_Numbers (Self);
        Note_Words (Self, Ranked (Words));
        Note_Endings (Self, Words);
        Note_Shapes (Self);
        Note_Members (Self, Words);
        return Self;
        end Built;

    function Group_Of (
            Length : in Positive
            ) return Natural is
        begin
        if Length <= 3 then
            return 0;
            end if;
        if Length <= 5 then
            return 1;
            end if;
        if Length <= 8 then
            return 2;
            end if;
        return 3;
        end Group_Of;
    --# Words are sorted by size into short, middling, long and very long.

    function Place_Of_Ending (
            Self : in Book;
            Word : in Wide_Wide_String
            ) return Natural is
        begin
        if not Has_Ending (Word) then
            return 0;
            end if;
        if not Self.Ending_Place.Contains (Ending_Of_Word (Word)) then
            return 0;
            end if;
        return Self.Ending_Place.Element (Ending_Of_Word (Word));
        end Place_Of_Ending;

    function Shape_Kind (
            Self : in Book;
            Word : in Wide_Wide_String
            ) return Symbol is
        Per_Group   : constant Positive := Natural (Self.Ending_Place.Length) + 1;
        Per_Capital : constant Positive := Size_Groups * Per_Group;
        Capital     : constant Natural := Boolean'Pos (Ada.Wide_Wide_Characters.Handling.Is_Upper (Word (Word'First)));
        Offset      : constant Natural :=
            Capital * Per_Capital + Group_Of (Word'Length) * Per_Group + Place_Of_Ending (Self, Word);
        begin
        return Self.First_Shape + Symbol_Count (Offset);
        end Shape_Kind;
    --# Shapes are numbered in order: first by capital, then by size, then by ending.

    function Kind_Of (
            Self  : in Book;
            Token : in Wide_Wide_String
            ) return Symbol is
        Sort : constant Tokens.Token_Sort := Tokens.Sort_Of (Token);
        begin
        if Self.Used = Unknown then
            return Unknown;
            --# A book that has read nothing knows no kinds.
            end if;
        if Sort = Tokens.Number then
            return Self.First_Number + Symbol_Count (Natural'Min (Token'Length, Number_Kinds)) - 1;
            end if;
        if Self.By_Text.Contains (Token) then
            return Self.By_Text.Element (Token);
            end if;
        if Sort = Tokens.Word then
            return Shape_Kind (Self, Token);
            end if;
        return Unknown;
        end Kind_Of;

    function Family_Of (
            Self : in Book;
            Kind : in Symbol
            ) return Kind_Family is
        begin
        return Self.Notes (Kind).Family;
        end Family_Of;

    function Text_Of (
            Self : in Book;
            Kind : in Symbol
            ) return Wide_Wide_String is
        begin
        return To_Wide_Wide_String (Self.Notes (Kind).Text);
        end Text_Of;

    function Figures_Of (
            Self : in Book;
            Kind : in Symbol
            ) return Natural is
        begin
        return Self.Notes (Kind).Figures;
        end Figures_Of;

    function Is_Capital (
            Self : in Book;
            Kind : in Symbol
            ) return Boolean is
        begin
        return Self.Notes (Kind).Capital;
        end Is_Capital;

    function Has_Members (
            Self : in Book;
            Kind : in Symbol
            ) return Boolean is
        begin
        return Self.Totals (Kind) > 0;
        end Has_Members;

    procedure Draw_Member (
            Self  : in     Book;
            Kind  : in     Symbol;
            Dice  : in out Random_Sources.Generator;
            Drawn :    out Texts.Wide_Text
            ) is
        Ticket : Natural;
        begin
        Random_Sources.Draw_Index (Dice, Self.Totals (Kind), Ticket);
        for Counted of Self.Members (Kind) loop
            if Ticket < Counted.Seen then
                Drawn := Counted.Word;
                return;
                end if;
            Ticket := Ticket - Counted.Seen;
            end loop;
        raise Program_Error with "the totals of the book do not add up";
        end Draw_Member;

    end Calipso.Kinds;
