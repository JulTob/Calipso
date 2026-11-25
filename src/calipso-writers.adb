with Ada.Strings.Wide_Wide_Unbounded;

with Calipso.Canvases;
with Calipso.Collapsing;

package body Calipso.Writers is

    Stop_Mark : constant Wide_Wide_Character := '.';

    overriding procedure Write (
            Self   : in     Flat_Writer;
            Dice   : in out Random_Sources.Generator;
            Words  : in     Positive;
            Result :    out Texts.Wide_Text
            ) is
        Board : Canvases.Canvas;
        begin
        for Count in 1 .. Words * Letters_Per_Word - 1 loop
            Canvases.Append_Blank (Board);
            end loop;
        if Alphabets.Contains (Self.Letters, Stop_Mark) then
            Canvases.Append_Given (Board, Alphabets.Symbol_Of (Self.Letters, Stop_Mark));
        else
            Canvases.Append_Blank (Board);
            end if;
        Collapsing.Collapse_All (Board, Self.Speller.all, Dice);
        Result := Ada.Strings.Wide_Wide_Unbounded.To_Unbounded_Wide_Wide_String (Pyramids.Plain_Text (Board, Self.Letters));
        end Write;
    --# A canvas of holes that ends in a full stop, collapsed by the letter brain alone.

    overriding procedure Write (
            Self   : in     Pyramid_Writer;
            Dice   : in out Random_Sources.Generator;
            Words  : in     Positive;
            Result :    out Texts.Wide_Text
            ) is
        begin
        Pyramids.Write (Self.Plan.all, Self.Speller.all, Self.Letters, Dice, Words, Self.Passing, Result);
        end Write;

    end Calipso.Writers;
