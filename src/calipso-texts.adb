with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.UTF_Encoding;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Text_IO;

package body Calipso.Texts is

    Line_Feed       : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);
    Carriage_Return : constant Wide_Wide_Character := Wide_Wide_Character'Val (13);

    procedure Open_For_Reading (
            File      : in out Ada.Text_IO.File_Type;
            File_Name : in     String
            ) is
        begin
        Ada.Text_IO.Open (File, Ada.Text_IO.In_File, File_Name);
        exception
        when Ada.Text_IO.Name_Error =>
            raise Reading_Error with "cannot find the file " & File_Name;
        when Ada.Text_IO.Use_Error =>
            raise Reading_Error with "cannot open the file " & File_Name;
        end Open_For_Reading;

    procedure Visit_Line (
            Line  : in String;
            Visit : not null access procedure (Char : in Wide_Wide_Character)
            ) is
        Letters_In_Line : constant Wide_Wide_String :=
            Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode (Line);
        begin
        for Char of Letters_In_Line loop
            if Char /= Carriage_Return then
                Visit (Char);
                end if;
            end loop;
        Visit (Line_Feed);
        end Visit_Line;

    procedure For_Each_Character (
            File_Name : in String;
            Visit     : not null access procedure (Char : in Wide_Wide_Character)
            ) is
        File : Ada.Text_IO.File_Type;
        begin
        Open_For_Reading (File, File_Name);
        while not Ada.Text_IO.End_Of_File (File) loop
            Visit_Line (Ada.Text_IO.Get_Line (File), Visit);
            end loop;
        Ada.Text_IO.Close (File);
        exception
        when Ada.Strings.UTF_Encoding.Encoding_Error =>
            Ada.Text_IO.Close (File);
            raise Reading_Error with File_Name & " is not valid UTF-8";
        end For_Each_Character;

    procedure Learn_Alphabet (
            File_Name : in     String;
            Letters   : in out Alphabets.Alphabet
            ) is

        procedure Note_Character (
                Char : in Wide_Wide_Character
                ) is
            begin
            Alphabets.Include (Letters, Char);
            end Note_Character;

        begin
        For_Each_Character (File_Name, Note_Character'Access);
        end Learn_Alphabet;

    function Bytes_Of (
            File_Name : in String
            ) return Ada.Strings.Unbounded.Unbounded_String is
        use Ada.Streams;
        File    : Stream_IO.File_Type;
        Buffer  : Stream_Element_Array (1 .. 4_096);
        Last    : Stream_Element_Offset;
        Content : Ada.Strings.Unbounded.Unbounded_String;
        begin
        Stream_IO.Open (File, Stream_IO.In_File, File_Name);
        loop
            Stream_IO.Read (File, Buffer, Last);
            for Index in 1 .. Last loop
                Ada.Strings.Unbounded.Append (Content, Character'Val (Buffer (Index)));
                end loop;
            exit when Last < Buffer'Last;
            end loop;
        Stream_IO.Close (File);
        return Content;
        exception
        when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
            raise Reading_Error with "cannot read the file " & File_Name;
        end Bytes_Of;

    function Whole_Text (
            File_Name : in String
            ) return Wide_Text is
        Gathered : Wide_Text;

        procedure Keep_Character (
                Char : in Wide_Wide_Character
                ) is
            begin
            Ada.Strings.Wide_Wide_Unbounded.Append (Gathered, Char);
            end Keep_Character;

        begin
        For_Each_Character (File_Name, Keep_Character'Access);
        return Gathered;
        end Whole_Text;

    function Read_Symbols (
            File_Name : in String;
            Letters   : in Alphabets.Alphabet
            ) return Symbol_Text is
        Text : Symbol_Text;

        procedure Store_Character (
                Char : in Wide_Wide_Character
                ) is
            Value : constant Symbol := Alphabets.Symbol_Of (Letters, Char);
            begin
            Text.Append (Value);
            end Store_Character;

        begin
        For_Each_Character (File_Name, Store_Character'Access);
        return Text;
        end Read_Symbols;

    function Part (
            Text  : in Symbol_Text;
            First : in Positive;
            Last  : in Natural
            ) return Symbol_Text is
        Piece : Symbol_Text;
        begin
        for Position in First .. Last loop
            Piece.Append (Text.Element (Position));
            end loop;
        return Piece;
        end Part;

    function Encoded (
            Plain   : in Wide_Wide_String;
            Letters : in Alphabets.Alphabet
            ) return Symbol_Text is
        Text  : Symbol_Text;
        Value : Symbol;
        begin
        for Char of Plain loop
            Value := Alphabets.Symbol_Of (Letters, Char);
            Text.Append (Value);
            end loop;
        return Text;
        end Encoded;

    function Decoded (
            Text    : in Symbol_Text;
            Letters : in Alphabets.Alphabet
            ) return Wide_Wide_String is
        Plain : Wide_Wide_String (1 .. Natural (Text.Length));
        begin
        for Position in 1 .. Natural (Text.Length) loop
            Plain (Position) := Alphabets.Character_Of (Letters, Text.Element (Position));
            end loop;
        return Plain;
        end Decoded;

    end Calipso.Texts;
