package body Calipso.Fragment_Counts is

    use type Ada.Containers.Hash_Type;

    Hash_Start : constant Ada.Containers.Hash_Type := 2166136261;
    Hash_Prime : constant Ada.Containers.Hash_Type := 16777619;
    --# FNV-1a recipe: a short, well-known way of turning a row
    --# of numbers into a single "scrambled" number for the table.

    function Hash (
            Piece : in Fragment
            ) return Ada.Containers.Hash_Type is
        Result : Ada.Containers.Hash_Type := Hash_Start;
        begin
        for Value of Piece loop
            Result := Result xor Ada.Containers.Hash_Type (Value);
            Result := Result * Hash_Prime;
            end loop;
        return Result;
        end Hash;

    function Slice (
            Text   : in Texts.Symbol_Text;
            First  : in Positive;
            Length : in Natural
            ) return Fragment is
        Piece : Fragment (1 .. Length);
        begin
        for Offset in 1 .. Length loop
            Piece (Offset) := Text.Element (First + Offset - 1);
            end loop;
        return Piece;
        end Slice;

    procedure Add_One (
            Table : in out Count_Table;
            Piece : in     Fragment
            ) is
        Place : constant Count_Maps.Cursor := Table.Counts.Find (Piece);
        Seen  : Natural;
        begin
        if Count_Maps.Has_Element (Place) then
            Seen := Count_Maps.Element (Place);
            Table.Counts.Replace_Element (Place, Seen + 1);
        else
            Table.Counts.Insert (Piece, 1);
            end if;
        end Add_One;

    function Count_Of (
            Table : in Count_Table;
            Piece : in Fragment
            ) return Natural is
        Place : constant Count_Maps.Cursor := Table.Counts.Find (Piece);
        begin
        if Count_Maps.Has_Element (Place) then
            return Count_Maps.Element (Place);
            end if;
        return 0;
        end Count_Of;

    function Distinct_Fragments (
            Table : in Count_Table
            ) return Natural is
        begin
        return Natural (Table.Counts.Length);
        end Distinct_Fragments;

    procedure Learn (
            Table   : in out Count_Table;
            Text    : in     Texts.Symbol_Text;
            Longest : in     Positive
            ) is
        Last : constant Natural := Text.Last_Index;
        begin
        for Start in 1 .. Last loop
            for Length in 1 .. Longest loop
                exit when Start + Length - 1 > Last;
                Add_One (Table, Slice (Text, Start, Length));
                end loop;
            end loop;
        end Learn;

    end Calipso.Fragment_Counts;
