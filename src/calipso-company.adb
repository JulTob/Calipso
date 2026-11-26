with Ada.Numerics.Long_Elementary_Functions;
with Ada.Wide_Wide_Characters.Handling;

package body Calipso.Company is

    use type Kinds.Kind_Family;
    use type Tokens.Token_Sort;

    Hash_Start : constant Hash_Number := 2_166_136_261;
    Hash_Prime : constant Hash_Number := 16_777_619;

    function Hash_Of (
            Text : in Wide_Wide_String
            ) return Hash_Number is
        Scrambled : Hash_Number := Hash_Start;
        begin
        for Char of Text loop
            Scrambled := (Scrambled xor Hash_Number (Wide_Wide_Character'Pos (Char))) * Hash_Prime;
            end loop;
        return Scrambled;
        end Hash_Of;

    function Folded (
            Options : in Settings;
            Word    : in Wide_Wide_String
            ) return Wide_Wide_String is
        begin
        if Options.Fold_Case then
            return Ada.Wide_Wide_Characters.Handling.To_Lower (Word);
            end if;
        return Word;
        end Folded;

    function Context_Size (
            Book    : in Kinds.Book;
            Options : in Settings
            ) return Positive is
        begin
        if Options.Context = As_Kinds then
            return Positive (Kinds.Kind_Count (Book));
            end if;
        return Options.Buckets;
        end Context_Size;

    function Code_Of (
            Book    : in Kinds.Book;
            Options : in Settings;
            Token   : in Wide_Wide_String
            ) return Positive is
        begin
        if Options.Context = As_Kinds then
            return Positive (Kinds.Kind_Of (Book, Token));
            end if;
        return 1 + Natural (Hash_Of (Folded (Options, Token)) mod Hash_Number (Options.Buckets));
        end Code_Of;
    --# The number a neighbour is counted under, from 1 to Context_Size.

    function Is_Counted (
            Book    : in Kinds.Book;
            Options : in Settings;
            Token   : in Wide_Wide_String
            ) return Boolean is
        begin
        if Tokens.Sort_Of (Token) /= Tokens.Word then
            return False;
            end if;
        if Options.Every_Word then
            return True;
            end if;
        return Kinds.Family_Of (Book, Kinds.Kind_Of (Book, Token)) /= Kinds.Word_Kind;
        end Is_Counted;

    procedure Find_Row (
            Self : in out Table;
            Key  : in     Wide_Wide_String;
            Row  :    out Positive
            ) is
        Width : constant Natural := 2 * Self.Options.Reach * Self.Size;
        begin
        if not Self.Places.Contains (Key) then
            Self.Words.Append (Key);
            Self.Places.Insert (Key, Natural (Self.Words.Length));
            Self.Rows.Append (Vectors.Vector'(1 .. Width => 0.0));
            Self.Seen.Append (0);
            end if;
        Row := Self.Places.Element (Key);
        end Find_Row;
    --# The row of this word, made (all zeros) the first time the word is met.

    procedure Count_One (
            Self    : in out Table;
            Row     : in     Positive;
            Feature : in     Positive
            ) is
        Counts : Vectors.Vector := Self.Rows.Element (Row);
        begin
        Counts (Feature) := Counts (Feature) + 1.0;
        Self.Rows.Replace_Element (Row, Counts);
        end Count_One;

    procedure Count_Neighbours (
            Self   : in out Table;
            Book   : in     Kinds.Book;
            Sample : in     Tokens.Token_List;
            Place  : in     Positive;
            Row    : in     Positive
            ) is
        Reach : constant Positive := Self.Options.Reach;
        Last  : constant Natural := Natural (Sample.Length);
        begin
        for Step in 1 .. Reach loop
            if Place - Step >= 1 then
                Count_One (
                    Self, Row, (Step - 1) * Self.Size + Code_Of (Book, Self.Options, Sample.Element (Place - Step))
                    );
                end if;
            if Place + Step <= Last then
                Count_One (
                    Self, Row, (Reach + Step - 1) * Self.Size + Code_Of (Book, Self.Options, Sample.Element (Place + Step))
                    );
                end if;
            end loop;
        end Count_Neighbours;

    function Softened (
            Row : in Vectors.Vector
            ) return Vectors.Vector is
        Eased : Vectors.Vector (Row'Range);
        begin
        for Index in Row'Range loop
            Eased (Index) := Ada.Numerics.Long_Elementary_Functions.Log (1.0 + Row (Index));
            end loop;
        return Vectors.Unit (Eased);
        end Softened;

    function Built (
            Sample  : in Tokens.Token_List;
            Book    : in Kinds.Book;
            Options : in Settings
            ) return Table is
        Self : Table;
        Row  : Positive;
        begin
        Self.Options := Options;
        Self.Size := Context_Size (Book, Options);
        for Place in 1 .. Natural (Sample.Length) loop
            if Is_Counted (Book, Options, Sample.Element (Place)) then
                Find_Row (Self, Folded (Options, Sample.Element (Place)), Row);
                Self.Seen.Replace_Element (Row, Self.Seen.Element (Row) + 1);
                Count_Neighbours (Self, Book, Sample, Place, Row);
                end if;
            end loop;
        if Options.Soften then
            for Number in 1 .. Natural (Self.Rows.Length) loop
                Self.Rows.Replace_Element (Number, Softened (Self.Rows.Element (Number)));
                end loop;
            end if;
        return Self;
        end Built;

    function Row_Count (
            Self : in Table
            ) return Natural is
        begin
        return Natural (Self.Words.Length);
        end Row_Count;

    function Has_Word (
            Self : in Table;
            Word : in Wide_Wide_String
            ) return Boolean is
        begin
        return Self.Places.Contains (Folded (Self.Options, Word));
        end Has_Word;

    function Row_Of (
            Self : in Table;
            Word : in Wide_Wide_String
            ) return Positive is
        begin
        return Self.Places.Element (Folded (Self.Options, Word));
        end Row_Of;

    function Vector_At (
            Self : in Table;
            Row  : in Positive
            ) return Vectors.Vector is
        begin
        return Self.Rows.Element (Row);
        end Vector_At;

    function Word_At (
            Self : in Table;
            Row  : in Positive
            ) return Wide_Wide_String is
        begin
        return Self.Words.Element (Row);
        end Word_At;

    function Seen_At (
            Self : in Table;
            Row  : in Positive
            ) return Natural is
        begin
        return Self.Seen.Element (Row);
        end Seen_At;

    function Vector_Of (
            Self : in Table;
            Word : in Wide_Wide_String
            ) return Vectors.Vector is
        begin
        return Vector_At (Self, Row_Of (Self, Word));
        end Vector_Of;

    function Rows_Of (
            Self : in Table
            ) return Vectors.Vector_List is
        begin
        return Self.Rows;
        end Rows_Of;

    end Calipso.Company;
