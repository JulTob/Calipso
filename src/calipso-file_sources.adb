with Ada.Containers;
with Ada.Strings.UTF_Encoding;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;

package body Calipso.File_Sources is

    Line_Feed       : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);
    Carriage_Return : constant Wide_Wide_Character := Wide_Wide_Character'Val (13);

    procedure Open (
            Self         : in out File_Source;
            File_Name    : in     String;
            Letters      : in     Alphabets.Alphabet;
            Piece_Length : in     Positive
            ) is
        begin
        Ada.Text_IO.Open (Self.File, Ada.Text_IO.In_File, File_Name);
        Self.Letters := Letters;
        Self.Piece_Length := Piece_Length;
        Self.Buffer.Clear;
        Self.Finished := False;
        exception
        when Ada.Text_IO.Name_Error | Ada.Text_IO.Use_Error =>
            raise Texts.Reading_Error with "cannot open the file " & File_Name;
        end Open;

    procedure Close (
            Self : in out File_Source
            ) is
        begin
        if Ada.Text_IO.Is_Open (Self.File) then
            Ada.Text_IO.Close (Self.File);
            end if;
        Self.Finished := True;
        end Close;

    procedure Read_One_Line (
            Self : in out File_Source
            ) is
        begin
        if Ada.Text_IO.End_Of_File (Self.File) then
            Self.Finished := True;
            return;
            end if;
        declare
            Line         : constant String := Ada.Text_IO.Get_Line (Self.File);
            Line_Letters : constant Wide_Wide_String :=
                Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode (Line);
            begin
            for Char of Line_Letters loop
                if Char /= Carriage_Return then
                    Self.Buffer.Append (Alphabets.Symbol_Of (Self.Letters, Char));
                    end if;
                end loop;
            Self.Buffer.Append (Alphabets.Symbol_Of (Self.Letters, Line_Feed));
            end;
        exception
        when Ada.Strings.UTF_Encoding.Encoding_Error =>
            raise Texts.Reading_Error with "the file is not valid UTF-8";
        end Read_One_Line;
    --# Moves one line of the file into the buffer, as symbols.

    overriding procedure Next_Piece (
            Self  : in out File_Source;
            Piece :    out Texts.Symbol_Text;
            Found :    out Boolean
            ) is
        begin
        while Natural (Self.Buffer.Length) < Self.Piece_Length and then not Self.Finished loop
            Read_One_Line (Self);
            end loop;
        if Natural (Self.Buffer.Length) < Self.Piece_Length then
            Piece.Clear;
            Found := False;
            return;
            end if;
        Piece := Texts.Part (Self.Buffer, 1, Self.Piece_Length);
        Self.Buffer.Delete_First (Ada.Containers.Count_Type (Self.Piece_Length));
        Found := True;
        end Next_Piece;

    end Calipso.File_Sources;
