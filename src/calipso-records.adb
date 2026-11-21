with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Long_Float_Text_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

package body Calipso.Records is

    Blanks : constant Ada.Strings.Maps.Character_Set :=
        Ada.Strings.Maps.To_Set (' ' & ASCII.HT & ASCII.CR);

    Tape_Mark    : constant String := "calipso-tape";
    End_Mark     : constant String := "end";
    --# The first and the last word of every brain file.
    Tape_Version : constant Long_Float := 1.0;
    --# The first number of every brain file. The last one says how many numbers there are.
    Largest_Whole : constant Long_Float := 1.0E15;
    Unit_Ending   : constant String := "_Brain";
    Quote         : constant Character := '"';

    ---------------------------------------------------------------
    --  Writing onto a tape and reading from it
    ---------------------------------------------------------------

    procedure Write_Word (
            Onto : in out Tape;
            Item : in     String
            ) is
        begin
        Onto.Words.Append (Item);
        end Write_Word;

    procedure Write_Count (
            Onto  : in out Tape;
            Count : in     Natural
            ) is
        begin
        Onto.Reals.Append (Long_Float (Count));
        end Write_Count;

    procedure Write_Real (
            Onto  : in out Tape;
            Value : in     Long_Float
            ) is
        begin
        Onto.Reals.Append (Value);
        end Write_Real;

    procedure Write_Reals (
            Onto   : in out Tape;
            Values : in     Numbers.Real_Row
            ) is
        Length : constant Natural := Natural (Values.Length);
        Filled : Natural := 0;
        begin
        for Index in 1 .. Length loop
            if Values.Element (Index) /= 0.0 then
                Filled := Filled + 1;
                end if;
            end loop;
        Write_Count (Onto, Length);
        Write_Count (Onto, Filled);
        for Index in 1 .. Length loop
            if Values.Element (Index) /= 0.0 then
                Write_Count (Onto, Index);
                Write_Real (Onto, Values.Element (Index));
                end if;
            end loop;
        end Write_Reals;

    function Read_Word (
            From : in out Tape
            ) return String is
        Place : constant Positive := From.Next_Word;
        begin
        if Place > Natural (From.Words.Length) then
            raise Record_Error with "the record ends too soon";
            end if;
        From.Next_Word := Place + 1;
        return From.Words.Element (Place);
        end Read_Word;

    function Read_Real (
            From : in out Tape
            ) return Long_Float is
        Place : constant Positive := From.Next_Real;
        begin
        if Place > Natural (From.Reals.Length) then
            raise Record_Error with "the record ends too soon";
            end if;
        From.Next_Real := Place + 1;
        return From.Reals.Element (Place);
        end Read_Real;

    function Is_Whole (
            Value : in Long_Float
            ) return Boolean is
        begin
        if abs Value >= Largest_Whole then
            return False;
            end if;
        return Long_Float'Floor (Value) = Value;
        end Is_Whole;

    function Read_Count (
            From : in out Tape
            ) return Natural is
        Value : constant Long_Float := Read_Real (From);
        begin
        if Value < 0.0 or else not Is_Whole (Value) or else Value > Long_Float (Natural'Last) then
            raise Record_Error with "expected a whole number";
            end if;
        return Natural (Value);
        end Read_Count;

    function Read_Reals (
            From : in out Tape
            ) return Numbers.Real_Row is
        Length : constant Natural := Read_Count (From);
        Filled : constant Natural := Read_Count (From);
        Values : Numbers.Real_Row := Numbers.Zeros (Length);
        Index  : Natural;
        Value  : Long_Float;
        begin
        for Entry_Number in 1 .. Filled loop
            Index := Read_Count (From);
            Value := Read_Real (From);
            if Index = 0 or else Index > Length then
                raise Record_Error with "a number is filed outside its row";
                end if;
            Values.Replace_Element (Index, Value);
            end loop;
        return Values;
        end Read_Reals;

    procedure Expect_Word (
            From   : in out Tape;
            Wanted : in     String
            ) is
        Found : constant String := Read_Word (From);
        begin
        if Found /= Wanted then
            raise Record_Error with "expected " & Wanted & ", found: " & Found;
            end if;
        end Expect_Word;

    ---------------------------------------------------------------
    --  The brain file
    ---------------------------------------------------------------

    function Padded (
            Item : in String
            ) return Word is
        Result : Word := (others => ' ');
        begin
        Result (1 .. Item'Length) := Item;
        return Result;
        end Padded;

    function Image (
            Value : in Long_Float
            ) return String is
        Buffer : String (1 .. 40);
        begin
        if not Value'Valid then
            raise Record_Error with "the brain holds a number that is not finite";
            end if;
        if Is_Whole (Value) then
            Ada.Long_Float_Text_IO.Put (To => Buffer, Item => Value, Aft => 1, Exp => 0);
        else
            Ada.Long_Float_Text_IO.Put (To => Buffer, Item => Value, Aft => 16, Exp => 3);
            end if;
        return Ada.Strings.Fixed.Trim (Buffer, Ada.Strings.Both);
        end Image;
    --# The number as Ada writes it: whole numbers as 144.0, the others with 17
    --# significant digits, which is enough to get back exactly the same number.

    function Unit_Name_For (
            File_Name : in String
            ) return String is
        use Ada.Strings.Unbounded;
        Stem      : constant String := Ada.Directories.Base_Name (File_Name);
        Name      : Unbounded_String;
        New_Part  : Boolean := True;
        begin
        for Char of Stem loop
            if Ada.Characters.Handling.Is_Letter (Char) and then Character'Pos (Char) < 128 then
                if New_Part then
                    Append (Name, Ada.Characters.Handling.To_Upper (Char));
                else
                    Append (Name, Char);
                    end if;
                New_Part := False;
            elsif Char in '0' .. '9' and then Length (Name) > 0 then
                Append (Name, Char);
                New_Part := False;
            elsif not New_Part then
                Append (Name, '_');
                New_Part := True;
                end if;
            end loop;
        if Length (Name) = 0 then
            return "Saved" & Unit_Ending;
            end if;
        if New_Part then
            return Slice (Name, 1, Length (Name) - 1) & Unit_Ending;
            --# The stem ended in a mark that became an underline: it is dropped.
            end if;
        return To_String (Name) & Unit_Ending;
        end Unit_Name_For;

    procedure Put_Item (
            File     : in     Ada.Text_IO.File_Type;
            Item     : in     String;
            Is_First : in out Boolean
            ) is
        begin
        if Is_First then
            Ada.Text_IO.Put_Line (File, "          " & Item);
        else
            Ada.Text_IO.Put_Line (File, "        , " & Item);
            end if;
        Is_First := False;
        end Put_Item;
    --# One item per line. The comma goes in front, so that no line needs to
    --# know whether it is the last one.

    procedure Put_Words (
            Self : in Tape;
            File : in Ada.Text_IO.File_Type
            ) is
        Is_First : Boolean := True;
        begin
        Ada.Text_IO.Put_Line (File, "    Words : constant Calipso.Records.Word_List := (");
        Put_Item (File, Quote & Padded (Tape_Mark) & Quote, Is_First);
        for Item of Self.Words loop
            Put_Item (File, Quote & Padded (Item) & Quote, Is_First);
            end loop;
        Put_Item (File, Quote & Padded (End_Mark) & Quote, Is_First);
        Ada.Text_IO.Put_Line (File, "        );");
        end Put_Words;

    procedure Put_Numbers (
            Self : in Tape;
            File : in Ada.Text_IO.File_Type
            ) is
        Is_First : Boolean := True;
        begin
        Ada.Text_IO.Put_Line (File, "    Numbers : constant Calipso.Records.Number_List := (");
        Put_Item (File, Image (Tape_Version), Is_First);
        for Value of Self.Reals loop
            Put_Item (File, Image (Value), Is_First);
            end loop;
        Put_Item (File, Image (Long_Float (Natural (Self.Reals.Length))), Is_First);
        Ada.Text_IO.Put_Line (File, "        );");
        end Put_Numbers;

    procedure Put_File (
            Self : in Tape;
            File : in Ada.Text_IO.File_Type;
            Unit : in String
            ) is
        begin
        Ada.Text_IO.Put_Line (File, "--  A Calipso brain.");
        Ada.Text_IO.Put_Line (File, "--");
        Ada.Text_IO.Put_Line (File, "--  This file is two things at once:");
        Ada.Text_IO.Put_Line (File, "--     data : Calipso reads it line by line when the brain is loaded.");
        Ada.Text_IO.Put_Line (File, "--     Ada  : it is the specification of a package, so it can also be");
        Ada.Text_IO.Put_Line (File, "--            compiled into a program.");
        Ada.Text_IO.Put_Line (File, "--  It is written by Calipso. Do not edit it by hand.");
        Ada.Text_IO.New_Line (File);
        Ada.Text_IO.Put_Line (File, "with Calipso.Records;");
        Ada.Text_IO.New_Line (File);
        Ada.Text_IO.Put_Line (File, "package " & Unit & " is");
        Ada.Text_IO.New_Line (File);
        Put_Words (Self, File);
        Ada.Text_IO.New_Line (File);
        Put_Numbers (Self, File);
        Ada.Text_IO.New_Line (File);
        Ada.Text_IO.Put_Line (File, "    end " & Unit & ";");
        end Put_File;

    procedure Save (
            Self      : in Tape;
            File_Name : in String
            ) is
        File : Ada.Text_IO.File_Type;
        begin
        Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, File_Name);
        Put_File (Self, File, Unit_Name_For (File_Name));
        Ada.Text_IO.Close (File);
        exception
        when Ada.Text_IO.Name_Error | Ada.Text_IO.Use_Error =>
            raise Record_Error with "cannot write the file " & File_Name;
        end Save;

    function Starts_With (
            Text   : in String;
            Prefix : in String
            ) return Boolean is
        begin
        if Text'Length < Prefix'Length then
            return False;
            end if;
        return Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix;
        end Starts_With;

    function Without_Comma (
            Line : in String
            ) return String is
        begin
        if Starts_With (Line, ",") then
            return Ada.Strings.Fixed.Trim (Line (Line'First + 1 .. Line'Last), Blanks, Blanks);
            end if;
        return Line;
        end Without_Comma;

    procedure Take_Word (
            Self : in out Tape;
            Item : in     String
            ) is
        Stop : constant Natural := Ada.Strings.Fixed.Index (Item, (1 => Quote), Ada.Strings.Backward);
        begin
        if Stop <= Item'First then
            raise Record_Error with "a word of the brain file is not closed: " & Item;
            end if;
        Self.Words.Append (Ada.Strings.Fixed.Trim (Item (Item'First + 1 .. Stop - 1), Ada.Strings.Right));
        end Take_Word;

    procedure Take_Number (
            Self : in out Tape;
            Item : in     String
            ) is
        begin
        Self.Reals.Append (Long_Float'Value (Item));
        exception
        when Constraint_Error =>
            raise Record_Error with "expected a number, found: " & Item;
        end Take_Number;

    procedure Take_Line (
            Self : in out Tape;
            Line : in     String
            ) is
        Bare : constant String := Ada.Strings.Fixed.Trim (Line, Blanks, Blanks);
        begin
        if Bare = "" or else Starts_With (Bare, "--") then
            return;
            --# An empty line or a comment.
            end if;
        declare
            Item  : constant String := Without_Comma (Bare);
            First : Character;
            begin
            if Item = "" then
                return;
                end if;
            First := Item (Item'First);
            if First = Quote then
                Take_Word (Self, Item);
            elsif First in '0' .. '9' or else First = '-' then
                Take_Number (Self, Item);
                end if;
            --# Any other line belongs to the Ada wrapping and says nothing as data.
            end;
        end Take_Line;

    procedure Remove_Frame (
            Self : in out Tape
            ) is
        Word_Count : constant Natural := Natural (Self.Words.Length);
        Real_Count : constant Natural := Natural (Self.Reals.Length);
        begin
        if Word_Count < 2 or else Real_Count < 2 then
            raise Record_Error with "this is not a brain file";
            end if;
        if Self.Words.First_Element /= Tape_Mark or else Self.Reals.First_Element /= Tape_Version then
            raise Record_Error with "this is not a brain file, or it is of a version I do not know";
            end if;
        if Self.Words.Last_Element /= End_Mark or else Self.Reals.Last_Element /= Long_Float (Real_Count - 2) then
            raise Record_Error with "the brain file is cut short or damaged";
            end if;
        Self.Words.Delete_First;
        Self.Words.Delete_Last;
        Self.Reals.Delete_First;
        Self.Reals.Delete_Last;
        Self.Next_Word := 1;
        Self.Next_Real := 1;
        end Remove_Frame;
    --# Checks the marks that open and close the two lists, and takes them away.

    procedure Read_Lines (
            Self      : in out Tape;
            File_Name : in     String
            ) is
        File : Ada.Text_IO.File_Type;
        begin
        Ada.Text_IO.Open (File, Ada.Text_IO.In_File, File_Name);
        while not Ada.Text_IO.End_Of_File (File) loop
            Take_Line (Self, Ada.Text_IO.Get_Line (File));
            end loop;
        Ada.Text_IO.Close (File);
        exception
        when Ada.Text_IO.Name_Error | Ada.Text_IO.Use_Error =>
            raise Record_Error with "cannot open the file " & File_Name;
        end Read_Lines;

    procedure Load (
            Self      :    out Tape;
            File_Name : in     String
            ) is
        Fresh : Tape;
        begin
        Read_Lines (Fresh, File_Name);
        Remove_Frame (Fresh);
        Self := Fresh;
        end Load;

    procedure Fill (
            Self         :    out Tape;
            From_Words   : in     Word_List;
            From_Numbers : in     Number_List
            ) is
        Fresh : Tape;
        begin
        for Item of From_Words loop
            Fresh.Words.Append (Ada.Strings.Fixed.Trim (Item, Ada.Strings.Right));
            end loop;
        for Value of From_Numbers loop
            Fresh.Reals.Append (Value);
            end loop;
        Remove_Frame (Fresh);
        Self := Fresh;
        end Fill;

    end Calipso.Records;
