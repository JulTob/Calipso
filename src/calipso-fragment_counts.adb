
package body Calipso.Fragment_Counts is

    use type Ada.Containers.Hash_Type;

    Hash_Start : constant Ada.Containers.Hash_Type := 2166136261;
    Hash_Prime : constant Ada.Containers.Hash_Type := 16777619;
    --# FNV-1a recipe: a short, well-known way of turning a row
    --# of numbers into a single "scrambled" number for the table.

    Check_Start : constant Ada.Containers.Hash_Type := 3141592653;
    --# The same recipe from another starting number gives the check number.

    function Scrambled (
            Piece : in Fragment;
            Start : in Ada.Containers.Hash_Type
            ) return Ada.Containers.Hash_Type is
        Result : Ada.Containers.Hash_Type := Start;
        begin
        for Value of Piece loop
            Result := Result xor Ada.Containers.Hash_Type (Value);
            Result := Result * Hash_Prime;
            end loop;
        return Result;
        end Scrambled;

    function Hash (
            Piece : in Fragment
            ) return Ada.Containers.Hash_Type is
        begin
        return Scrambled (Piece, Hash_Start);
        end Hash;

    function Check_Of (
            Piece : in Fragment
            ) return Ada.Containers.Hash_Type is
        begin
        return Scrambled (Piece, Check_Start);
        end Check_Of;

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

    function Slot_Of (
            Table : in Count_Table;
            Piece : in Fragment
            ) return Positive is
        Scrambled : constant Ada.Containers.Hash_Type := Hash (Piece);
        Limit_Of  : constant Ada.Containers.Hash_Type := Ada.Containers.Hash_Type (Table.Capacity);
        begin
        return Natural (Scrambled mod Limit_Of) + 1;
        end Slot_Of;

    procedure Limit (
            Table    : in out Count_Table;
            Capacity : in     Natural
            ) is
        begin
        Table.Counts.Clear;
        Table.Capacity := Capacity;
        Table.Slots := Slot_Vectors.To_Vector (0, Ada.Containers.Count_Type (Capacity));
        Table.Checks := Check_Vectors.To_Vector (0, Ada.Containers.Count_Type (Capacity));
        end Limit;

    function Capacity_Of (
            Table : in Count_Table
            ) return Natural is
        begin
        return Table.Capacity;
        end Capacity_Of;

    procedure Add_One_Bounded (
            Table : in out Count_Table;
            Piece : in     Fragment
            ) is
        Slot  : constant Positive := Slot_Of (Table, Piece);
        Check : constant Ada.Containers.Hash_Type := Check_Of (Piece);
        Seen  : constant Natural := Table.Slots.Element (Slot);
        begin
        if Seen = 0 then
            Table.Checks.Replace_Element (Slot, Check);
            Table.Slots.Replace_Element (Slot, 1);
        elsif Table.Checks.Element (Slot) = Check then
            Table.Slots.Replace_Element (Slot, Seen + 1);
        elsif Seen = 1 then
            Table.Checks.Replace_Element (Slot, Check);
            --# The owner's count would reach 0: the newcomer takes the counter, with a count of 1.
        else
            Table.Slots.Replace_Element (Slot, Seen - 1);
            end if;
        end Add_One_Bounded;

    function Count_Bounded (
            Table : in Count_Table;
            Piece : in Fragment
            ) return Natural is
        Slot : constant Positive := Slot_Of (Table, Piece);
        begin
        if Table.Checks.Element (Slot) /= Check_Of (Piece) then
            return 0;
            end if;
        return Table.Slots.Element (Slot);
        end Count_Bounded;

    procedure Add_One (
            Table : in out Count_Table;
            Piece : in     Fragment
            ) is
        Place : Count_Maps.Cursor;
        Seen  : Natural;
        begin
        if Table.Capacity > 0 then
            Add_One_Bounded (Table, Piece);
            return;
            end if;
        Place := Table.Counts.Find (Piece);
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
        Place : Count_Maps.Cursor;
        begin
        if Table.Capacity > 0 then
            return Count_Bounded (Table, Piece);
            end if;
        Place := Table.Counts.Find (Piece);
        if Count_Maps.Has_Element (Place) then
            return Count_Maps.Element (Place);
            end if;
        return 0;
        end Count_Of;

    function Distinct_Fragments (
            Table : in Count_Table
            ) return Natural is
        Used : Natural := 0;
        begin
        if Table.Capacity = 0 then
            return Natural (Table.Counts.Length);
            end if;
        for Slot in 1 .. Table.Capacity loop
            if Table.Slots.Element (Slot) > 0 then
                Used := Used + 1;
                end if;
            end loop;
        return Used;
        end Distinct_Fragments;
    --# With bounded memory: how many counters are in use.

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

    procedure Save_Bounded (
            Table : in     Count_Table;
            Tape  : in out Records.Tape
            ) is
        begin
        Records.Write_Count (Tape, Distinct_Fragments (Table));
        for Slot in 1 .. Table.Capacity loop
            if Table.Slots.Element (Slot) > 0 then
                Records.Write_Count (Tape, Slot);
                Records.Write_Real (Tape, Long_Float (Table.Checks.Element (Slot)));
                --# A check number can be larger than the largest whole number of the machine: it goes as a real.
                Records.Write_Count (Tape, Table.Slots.Element (Slot));
                end if;
            end loop;
        end Save_Bounded;

    procedure Save_Exact (
            Table : in     Count_Table;
            Tape  : in out Records.Tape
            ) is
        begin
        Records.Write_Count (Tape, Natural (Table.Counts.Length));
        for Place in Table.Counts.Iterate loop
            declare
                Piece : constant Fragment := Count_Maps.Key (Place);
                begin
                Records.Write_Count (Tape, Piece'Length);
                for Value of Piece loop
                    Records.Write_Count (Tape, Natural (Value));
                    end loop;
                Records.Write_Count (Tape, Count_Maps.Element (Place));
                end;
            end loop;
        end Save_Exact;

    procedure Save (
            Table : in     Count_Table;
            Tape  : in out Records.Tape
            ) is
        begin
        Records.Write_Count (Tape, Table.Capacity);
        if Table.Capacity > 0 then
            Save_Bounded (Table, Tape);
        else
            Save_Exact (Table, Tape);
            end if;
        end Save;

    procedure Load_One_Fragment (
            Table : in out Count_Table;
            Tape  : in out Records.Tape
            ) is
        Length : constant Natural := Records.Read_Count (Tape);
        Piece  : Fragment (1 .. Length);
        begin
        for Index in 1 .. Length loop
            Piece (Index) := Symbol (Records.Read_Count (Tape));
            end loop;
        Table.Counts.Insert (Piece, Records.Read_Count (Tape));
        end Load_One_Fragment;

    procedure Load (
            Table : in out Count_Table;
            Tape  : in out Records.Tape
            ) is
        Capacity : constant Natural := Records.Read_Count (Tape);
        Entries  : Natural;
        Slot     : Natural;
        Check    : Long_Float;
        begin
        Limit (Table, Capacity);
        Entries := Records.Read_Count (Tape);
        for Entry_Number in 1 .. Entries loop
            if Capacity > 0 then
                Slot := Records.Read_Count (Tape);
                Check := Records.Read_Real (Tape);
                Table.Checks.Replace_Element (Slot, Ada.Containers.Hash_Type (Check));
                Table.Slots.Replace_Element (Slot, Records.Read_Count (Tape));
            else
                Load_One_Fragment (Table, Tape);
                end if;
            end loop;
        end Load;

    end Calipso.Fragment_Counts;
