--  A source that reads a file from start to end, never loading it whole.
--
--  It keeps only a small buffer in memory, so the file can be of any size.

with Ada.Text_IO;

with Calipso.Alphabets;
with Calipso.Sources;
with Calipso.Texts;

package Calipso.File_Sources is

    type File_Source is limited new Sources.Source with private;

    procedure Open (
            Self         : in out File_Source;
            File_Name    : in     String;
            Letters      : in     Alphabets.Alphabet;
            Piece_Length : in     Positive
            );
    --# Raises Texts.Reading_Error if the file cannot be opened.

    procedure Close (
            Self : in out File_Source
            );

    overriding procedure Next_Piece (
            Self  : in out File_Source;
            Piece :    out Texts.Symbol_Text;
            Found :    out Boolean
            );
    --# The pieces follow one another in the file. What is left at the end,
    --# if it is shorter than a piece, is dropped.

private

    type File_Source is limited new Sources.Source with record
        File         : Ada.Text_IO.File_Type;
        Letters      : Alphabets.Alphabet;
        Piece_Length : Positive := 1;
        Buffer       : Texts.Symbol_Text;
        --# Symbols already read from the file and not handed out yet.
        Finished     : Boolean := True;
        end record;

    end Calipso.File_Sources;
