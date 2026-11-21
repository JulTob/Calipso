--  Write and read canvases as text.
--
--  Template notation:
--
--     _        a hole of one cell
--     [25]     a hole of 25 cells
--     [...]    a hole of the default size
--     \n       a line break (paragraph boundary)
--     everything else is given letters, as they are

with Calipso.Alphabets;
with Calipso.Canvases;
with Calipso.Texts;

package Calipso.Templates is

    Blank_Mark   : constant Wide_Wide_Character := '_';
    Hole_Opening : constant Wide_Wide_Character := '[';
    Hole_Closing : constant Wide_Wide_Character := ']';

    Default_Hole : constant Positive := 30;
    Largest_Hole : constant Positive := 10_000;

    function Parsed (
            Template : in Wide_Wide_String;
            Letters  : in Alphabets.Alphabet
            ) return Canvases.Canvas;

    function From_Text (
            Text   : in Texts.Symbol_Text;
            First  : in Positive;
            Length : in Natural
            ) return Canvases.Canvas
        with Pre => First + Length - 1 <= Text.Last_Index;
    --# A canvas with a piece of real text, all of it as given letters.

    function Rendered (
            Board        : in Canvases.Canvas;
            Letters      : in Alphabets.Alphabet;
            Mark_Guesses : in Boolean := False
            ) return Wide_Wide_String;
    --# With Mark_Guesses, what the model wrote comes out in brackets.

    end Calipso.Templates;
