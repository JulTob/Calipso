--  Change one point, and let the rest find its place again.
--
--  The text is read from left to right. Each cell asks: "given my neighbours as
--  they are now, and given how sure I was of what I held, what should I be?" If
--  the answer is another symbol, the cell is rewritten. The text is read again
--  and again until a whole reading changes nothing. Such a text is a FIXED POINT:
--  reading it once more gives the same text.
--
--  A pinned change is a cell whose anchor is sure (1) of the new symbol. A cell
--  "surely wrong" (0) must change. Every other cell resists as its certainty says.
--
--  It mirrors reference/calipso_ref/settling.py.

with Calipso.Anchored_Oracles;
with Calipso.Canvases;
with Calipso.Certainties;
with Calipso.Oracles;
with Calipso.Texts;

package Calipso.Settling is

    Default_Passes : constant Positive := 8;

    type Report is record
        Passes     : Natural := 0;
        Changes    : Natural := 0;
        --# How many times a cell was rewritten.
        Is_Settled : Boolean := False;
        --# A whole reading went by with no change.
        end record;

    function Written (
            Text : in Texts.Symbol_Text
            ) return Canvases.Canvas
        with Post => Canvases.Blank_Count (Written'Result) = 0;
    --# A canvas with the text on it, every cell free to be rewritten.

    function Even_Anchors (
            Text : in Texts.Symbol_Text;
            Sure : in Certainties.Certainty
            ) return Anchored_Oracles.Anchor_List;
    --# Every cell remembers its own symbol, all with the same certainty.

    procedure Settle (
            Board   : in out Canvases.Canvas;
            Model   : in     Oracles.Oracle'Class;
            Anchors : in     Anchored_Oracles.Anchor_List;
            Outcome :    out Report;
            Passes  : in     Positive := Default_Passes
            )
        with
            Pre  => Canvases.Blank_Count (Board) = 0,
            Post => Canvases.Blank_Count (Board) = 0;
    --# Given cells never change. Guessed cells are read again, at most Passes times.

    end Calipso.Settling;
