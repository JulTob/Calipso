--  The level of words reads a text as TOKENS: the pieces a reader takes whole.
--
--     Word   : a run of letters             "casa"
--     Number : a run of digits              "1704"
--     Mark   : one sign, alone              "."  ","  "("
--     Break  : the end of a paragraph (a blank line between two lines of text)
--
--  Blanks between tokens are not tokens: they are put back when the text is written.
--
--  It mirrors reference/calipso_ref/tokens.py.

with Ada.Containers.Indefinite_Vectors;

package Calipso.Tokens is

    type Token_Sort is (Word, Number, Mark, Break);

    package Token_Vectors is new Ada.Containers.Indefinite_Vectors (
            Index_Type   => Positive,
            Element_Type => Wide_Wide_String
            );

    subtype Token_List is Token_Vectors.Vector;

    Line_Feed  : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);
    Break_Text : constant Wide_Wide_String := (1 => Line_Feed);
    --# How a Break is written as a token.

    function Is_Letter (
            Char : in Wide_Wide_Character
            ) return Boolean;

    function Is_Digit (
            Char : in Wide_Wide_Character
            ) return Boolean;

    function Is_Blank (
            Char : in Wide_Wide_Character
            ) return Boolean;
    --# Spaces, tabs and ends of line: what separates tokens.

    function Sort_Of (
            Token : in Wide_Wide_String
            ) return Token_Sort
        with Pre => Token'Length >= 1;

    function Split (
            Text : in Wide_Wide_String
            ) return Token_List;
    --# The tokens of a text, in order. A token keeps the positions it had in the
    --# text: ask for Token'First and Token'Last, never suppose it starts at 1.

    end Calipso.Tokens;
