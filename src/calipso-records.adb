with Ada.Long_Float_Text_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;

package body Calipso.Records is

    Blanks : constant Ada.Strings.Maps.Character_Set :=
        Ada.Strings.Maps.To_Set (' ' & ASCII.HT & ASCII.CR);

    procedure Write_Word (
            File : in Ada.Text_IO.File_Type;
            Word : in String
            ) is
        begin
        Ada.Text_IO.Put_Line (File, Word);
        end Write_Word;

    procedure Write_Count (
            File  : in Ada.Text_IO.File_Type;
            Count : in Natural
            ) is
        Image : constant String := Natural'Image (Count);
        begin
        Ada.Text_IO.Put_Line (File, Ada.Strings.Fixed.Trim (Image, Ada.Strings.Left));
        end Write_Count;

    procedure Write_Real (
            File  : in Ada.Text_IO.File_Type;
            Value : in Long_Float
            ) is
        begin
        Ada.Long_Float_Text_IO.Put (
            File => File,
            Item => Value,
            Fore => 1,
            Aft  => 16,
            Exp  => 3
            );
        Ada.Text_IO.New_Line (File);
        end Write_Real;

    procedure Write_Reals (
            File   : in Ada.Text_IO.File_Type;
            Values : in Numbers.Real_Row
            ) is
        Length : constant Natural := Natural (Values.Length);
        Filled : Natural := 0;
        begin
        for Index in 1 .. Length loop
            if Values.Element (Index) /= 0.0 then
                Filled := Filled + 1;
                end if;
            end loop;
        Write_Count (File, Length);
        Write_Count (File, Filled);
        for Index in 1 .. Length loop
            if Values.Element (Index) /= 0.0 then
                Write_Count (File, Index);
                Write_Real (File, Values.Element (Index));
                end if;
            end loop;
        end Write_Reals;

    function Read_Word (
            File : in Ada.Text_IO.File_Type
            ) return String is
        begin
        if Ada.Text_IO.End_Of_File (File) then
            raise Record_Error with "the file ends too soon";
            end if;
        return Ada.Strings.Fixed.Trim (Ada.Text_IO.Get_Line (File), Blanks, Blanks);
        end Read_Word;

    function Read_Count (
            File : in Ada.Text_IO.File_Type
            ) return Natural is
        Word : constant String := Read_Word (File);
        begin
        return Natural'Value (Word);
        exception
        when Constraint_Error =>
            raise Record_Error with "expected a whole number, found: " & Word;
        end Read_Count;

    function Read_Real (
            File : in Ada.Text_IO.File_Type
            ) return Long_Float is
        Word : constant String := Read_Word (File);
        begin
        return Long_Float'Value (Word);
        exception
        when Constraint_Error =>
            raise Record_Error with "expected a real number, found: " & Word;
        end Read_Real;

    function Read_Reals (
            File : in Ada.Text_IO.File_Type
            ) return Numbers.Real_Row is
        Length : constant Natural := Read_Count (File);
        Filled : constant Natural := Read_Count (File);
        Values : Numbers.Real_Row := Numbers.Zeros (Length);
        Index  : Natural;
        begin
        for Entry_Number in 1 .. Filled loop
            Index := Read_Count (File);
            Values.Replace_Element (Index, Read_Real (File));
            end loop;
        return Values;
        end Read_Reals;

    procedure Expect_Word (
            File   : in Ada.Text_IO.File_Type;
            Wanted : in String
            ) is
        Found : constant String := Read_Word (File);
        begin
        if Found /= Wanted then
            raise Record_Error with "expected " & Wanted & ", found: " & Found;
            end if;
        end Expect_Word;

    end Calipso.Records;
