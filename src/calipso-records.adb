with Ada.Characters.Handling;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Long_Float_Text_IO;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Unchecked_Conversion;

with Interfaces;

with Calipso.Texts;

package body Calipso.Records is

    use type Interfaces.Unsigned_64;

    subtype Unsigned_64 is Interfaces.Unsigned_64;

    Blanks : constant Ada.Strings.Maps.Character_Set :=
        Ada.Strings.Maps.To_Set (' ' & ASCII.HT & ASCII.CR);

    Tape_Mark    : constant String := "calipso-tape";
    End_Mark     : constant String := "end";
    --# The first and the last word of every brain file.
    Tape_Version : constant Long_Float := 1.0;
    --# The first number of every brain file. The last one says how many numbers there are.
    Packed_Mark   : constant String := "ZMB1";
    --# The four bytes that open every packed brain file.
    Packed_Ending : constant String := ".zmb";
    Tag_Whole     : constant Unsigned_64 := 0;
    Tag_Real      : constant Unsigned_64 := 1;
    Largest_Packed_Whole : constant Long_Float := 9_007_199_254_740_992.0;
    Largest_Scale        : constant Unsigned_64 := 9_007_199_254_740_992;
    --# 2 to the power 53: up to here every whole number is exact as a real.

    subtype Byte_Text is Ada.Strings.Unbounded.Unbounded_String;
    --# A row of bytes, one character per byte.

    pragma Compile_Time_Error (
        Long_Float'Size /= 64,
        "the packed brain file needs real numbers of 64 bits"
        );

    function To_Bits is new Ada.Unchecked_Conversion (Long_Float, Unsigned_64);
    function To_Real is new Ada.Unchecked_Conversion (Unsigned_64, Long_Float);
    --# The 64 bits of a real number, seen as a whole number, and back.

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

    procedure Save_As_Text (
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
        end Save_As_Text;

    ---------------------------------------------------------------
    --  The packed brain file
    ---------------------------------------------------------------

    function Is_Packed_Name (
            File_Name : in String
            ) return Boolean is
        Size : constant Natural := Packed_Ending'Length;
        begin
        if File_Name'Length < Size then
            return False;
            end if;
        return Ada.Characters.Handling.To_Lower (File_Name (File_Name'Last - Size + 1 .. File_Name'Last)) = Packed_Ending;
        end Is_Packed_Name;

    procedure Put_Byte (
            Bytes : in out Byte_Text;
            Value : in     Unsigned_64
            ) is
        begin
        Ada.Strings.Unbounded.Append (Bytes, Character'Val (Natural (Value)));
        end Put_Byte;

    procedure Put_Whole (
            Bytes : in out Byte_Text;
            Value : in     Unsigned_64
            ) is
        Rest : Unsigned_64 := Value;
        begin
        while Rest >= 128 loop
            Put_Byte (Bytes, (Rest mod 128) + 128);
            Rest := Rest / 128;
            end loop;
        Put_Byte (Bytes, Rest);
        end Put_Whole;
    --# A whole number in as few bytes as it needs: 7 bits in each byte, and
    --# the top bit says "there is more".

    function Is_Plain_Whole (
            Value : in Long_Float
            ) return Boolean is
        begin
        if Value < 0.0 or else Value >= Largest_Packed_Whole then
            return False;
            end if;
        if Long_Float'Floor (Value) /= Value then
            return False;
            end if;
        return Long_Float'Copy_Sign (1.0, Value) > 0.0;
        --# Zero with a minus sign is kept as a real, so that nothing at all is lost.
        end Is_Plain_Whole;

    procedure Put_Number (
            Bytes : in out Byte_Text;
            Value : in     Long_Float
            ) is
        Bits : Unsigned_64;
        begin
        if Is_Plain_Whole (Value) then
            Put_Byte (Bytes, Tag_Whole);
            Put_Whole (Bytes, Unsigned_64 (Value));
            return;
            end if;
        Put_Byte (Bytes, Tag_Real);
        Bits := To_Bits (Value);
        for Count in 1 .. 8 loop
            Put_Byte (Bytes, Bits mod 256);
            Bits := Bits / 256;
            end loop;
        end Put_Number;

    function Packed (
            Self : in Tape
            ) return Byte_Text is
        Bytes : Byte_Text := Ada.Strings.Unbounded.To_Unbounded_String (Packed_Mark);
        begin
        Put_Whole (Bytes, Unsigned_64 (Self.Words.Length));
        for Item of Self.Words loop
            Put_Whole (Bytes, Unsigned_64 (Item'Length));
            Ada.Strings.Unbounded.Append (Bytes, Item);
            end loop;
        Put_Whole (Bytes, Unsigned_64 (Self.Reals.Length));
        for Value of Self.Reals loop
            Put_Number (Bytes, Value);
            end loop;
        return Bytes;
        end Packed;

    procedure Save_Packed (
            Self      : in Tape;
            File_Name : in String
            ) is
        use Ada.Streams;
        File : Stream_IO.File_Type;
        begin
        Stream_IO.Create (File, Stream_IO.Out_File, File_Name);
        String'Write (Stream_IO.Stream (File), Ada.Strings.Unbounded.To_String (Packed (Self)));
        Stream_IO.Close (File);
        exception
        when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
            raise Record_Error with "cannot write the file " & File_Name;
        end Save_Packed;

    procedure Save (
            Self      : in Tape;
            File_Name : in String
            ) is
        begin
        if Is_Packed_Name (File_Name) then
            Save_Packed (Self, File_Name);
        else
            Save_As_Text (Self, File_Name);
            end if;
        end Save;

    type Unpacking is record
        Data     : Byte_Text;
        Position : Positive := 1;
        end record;
    --# The bytes of a packed file, and how far they have been read.

    function Take_Byte (
            Reading : in out Unpacking
            ) return Unsigned_64 is
        Place : constant Positive := Reading.Position;
        begin
        if Place > Ada.Strings.Unbounded.Length (Reading.Data) then
            raise Record_Error with "the packed brain file is cut short";
            end if;
        Reading.Position := Place + 1;
        return Character'Pos (Ada.Strings.Unbounded.Element (Reading.Data, Place));
        end Take_Byte;

    function Take_Whole (
            Reading : in out Unpacking
            ) return Unsigned_64 is
        Value : Unsigned_64 := 0;
        Scale : Unsigned_64 := 1;
        Byte  : Unsigned_64;
        begin
        loop
            Byte := Take_Byte (Reading);
            Value := Value + (Byte mod 128) * Scale;
            if Byte < 128 then
                return Value;
                end if;
            Scale := Scale * 128;
            if Scale > Largest_Scale then
                raise Record_Error with "the packed brain file is damaged";
                end if;
            end loop;
        end Take_Whole;

    function Take_Count (
            Reading : in out Unpacking
            ) return Natural is
        Value : constant Unsigned_64 := Take_Whole (Reading);
        begin
        if Value > Unsigned_64 (Natural'Last) then
            raise Record_Error with "the packed brain file is damaged";
            end if;
        return Natural (Value);
        end Take_Count;
    --# A whole number that has to count things in memory.

    function Take_Packed_Number (
            Reading : in out Unpacking
            ) return Long_Float is
        Tag   : constant Unsigned_64 := Take_Byte (Reading);
        Bits  : Unsigned_64 := 0;
        Scale : Unsigned_64 := 1;
        Byte  : Unsigned_64;
        begin
        if Tag = Tag_Whole then
            return Long_Float (Take_Whole (Reading));
            end if;
        if Tag /= Tag_Real then
            raise Record_Error with "the packed brain file is damaged";
            end if;
        for Count in 1 .. 8 loop
            Byte := Take_Byte (Reading);
            Bits := Bits + Byte * Scale;
            Scale := Scale * 256;
            end loop;
        return To_Real (Bits);
        end Take_Packed_Number;

    procedure Take_Packed_Word (
            Self    : in out Tape;
            Reading : in out Unpacking
            ) is
        Size    : constant Natural := Take_Count (Reading);
        Letters : String (1 .. Natural'Min (Size, Word_Length));
        Byte    : Unsigned_64;
        begin
        if Size > Word_Length then
            raise Record_Error with "the packed brain file is damaged";
            end if;
        for Index in 1 .. Size loop
            Byte := Take_Byte (Reading);
            Letters (Index) := Character'Val (Natural (Byte));
            end loop;
        Self.Words.Append (Letters);
        end Take_Packed_Word;

    procedure Unpack (
            Self  : in out Tape;
            Bytes : in     Byte_Text
            ) is
        Reading    : Unpacking;
        Word_Count : Natural;
        Real_Count : Natural;
        Value      : Long_Float;
        begin
        Reading.Data := Bytes;
        Reading.Position := Packed_Mark'Length + 1;
        Word_Count := Take_Count (Reading);
        for Count in 1 .. Word_Count loop
            Take_Packed_Word (Self, Reading);
            end loop;
        Real_Count := Take_Count (Reading);
        for Count in 1 .. Real_Count loop
            Value := Take_Packed_Number (Reading);
            Self.Reals.Append (Value);
            end loop;
        end Unpack;

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

    procedure Read_Text (
            Self  : in out Tape;
            Bytes : in     Byte_Text
            ) is
        use Ada.Strings.Unbounded;
        Line : Unbounded_String;
        Char : Character;
        begin
        for Position in 1 .. Length (Bytes) loop
            Char := Element (Bytes, Position);
            if Char = ASCII.LF then
                Take_Line (Self, To_String (Line));
                Line := Null_Unbounded_String;
            else
                Append (Line, Char);
                end if;
            end loop;
        Take_Line (Self, To_String (Line));
        end Read_Text;
    --# Takes the brain file apart into lines, and each line into what it says.

    function Is_Packed (
            Bytes : in Byte_Text
            ) return Boolean is
        Size : constant Natural := Packed_Mark'Length;
        begin
        if Ada.Strings.Unbounded.Length (Bytes) < Size then
            return False;
            end if;
        return Ada.Strings.Unbounded.Slice (Bytes, 1, Size) = Packed_Mark;
        end Is_Packed;

    procedure Load (
            Self      :    out Tape;
            File_Name : in     String
            ) is
        Fresh : Tape;
        Bytes : Byte_Text;
        begin
        Bytes := Texts.Bytes_Of (File_Name);
        if Is_Packed (Bytes) then
            Unpack (Fresh, Bytes);
        else
            Read_Text (Fresh, Bytes);
            Remove_Frame (Fresh);
            end if;
        Self := Fresh;
        exception
        when Texts.Reading_Error =>
            raise Record_Error with "cannot open the file " & File_Name;
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
