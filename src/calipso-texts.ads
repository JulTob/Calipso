--  Go from a text file to a row of symbols.
--
--  Border with the outside world: outside, text is UTF-8 bytes;
--  inside, it is symbols. This is the only place where a file is opened.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Ada.Strings.Wide_Wide_Unbounded;

with Calipso.Alphabets;

package Calipso.Texts is

    package Symbol_Vectors is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Symbol
            );

    subtype Symbol_Text is Symbol_Vectors.Vector;
    --# A text already translated: a row of symbols, numbered from 1.

    Reading_Error : exception;
    --# The file does not exist, cannot be opened or is not valid UTF-8.

    procedure For_Each_Character (
            File_Name : in String;
            Visit     : not null access procedure (Char : in Wide_Wide_Character)
            );
    --# Walks the file letter by letter and calls Visit with each one.
    --# Every line ends in a line feed, the last one too.

    procedure Learn_Alphabet (
            File_Name : in     String;
            Letters   : in out Alphabets.Alphabet
            );
    --# First pass: note every new letter, in order of appearance.

    function Read_Symbols (
            File_Name : in String;
            Letters   : in Alphabets.Alphabet
            ) return Symbol_Text;
    --# Second pass: translate every letter into its symbol.

    function Bytes_Of (
            File_Name : in String
            ) return Ada.Strings.Unbounded.Unbounded_String;
    --# The bytes of a file, whatever they are, one character per byte.
    --# Raises Reading_Error if the file cannot be read.

    subtype Wide_Text is Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
    --# Text as letters, of any length. It lives on the heap, so it can be large.

    function Whole_Text (
            File_Name : in String
            ) return Wide_Text;
    --# All the letters of a file, as they are. Raises Reading_Error like the others.

    function Part (
            Text  : in Symbol_Text;
            First : in Positive;
            Last  : in Natural
            ) return Symbol_Text
        with Pre => Last <= Text.Last_Index;
    --# The piece of the text from First to Last, as a new text.

    function Encoded (
            Plain   : in Wide_Wide_String;
            Letters : in Alphabets.Alphabet
            ) return Symbol_Text;

    function Decoded (
            Text    : in Symbol_Text;
            Letters : in Alphabets.Alphabet
            ) return Wide_Wide_String;

    end Calipso.Texts;
