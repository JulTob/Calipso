--  One contract, two ways of writing.
--
--     Flat_Writer    : one level. Every cell is a letter, and all of them are holes.
--     Pyramid_Writer : two levels. First the kinds of word, then the letters.
--
--  A program asks a Writer for a text and does not need to know which one it has.
--  A third way of writing is one more type that keeps this contract.
--
--  It mirrors reference/calipso_ref/writers.py.

with Calipso.Alphabets;
with Calipso.Oracles;
with Calipso.Pyramids;
with Calipso.Random_Sources;
with Calipso.Texts;

package Calipso.Writers is

    Letters_Per_Word : constant Positive := 6;
    --# A word and its space, more or less: how the flat writer turns "words" into cells.

    type Writer is interface;

    procedure Write (
            Self   : in     Writer;
            Dice   : in out Random_Sources.Generator;
            Words  : in     Positive;
            Result :    out Texts.Wide_Text
            ) is abstract;
    --# A text of about Words words.

    type Flat_Writer (
            Speller : not null access constant Oracles.Oracle'Class
            ) is new Writer with record
        Letters : Alphabets.Alphabet;
        end record;
    --# Speller is the letter brain, and Letters the alphabet it was taught with.

    overriding procedure Write (
            Self   : in     Flat_Writer;
            Dice   : in out Random_Sources.Generator;
            Words  : in     Positive;
            Result :    out Texts.Wide_Text
            );

    type Pyramid_Writer (
            Plan    : not null access constant Pyramids.Pyramid;
            Speller : not null access constant Oracles.Oracle'Class
            ) is new Writer with record
        Letters : Alphabets.Alphabet;
        Passing : Pyramids.Handover := Pyramids.Spell;
        end record;
    --# Plan is the level of kinds. Speller and Letters are the level of letters.

    overriding procedure Write (
            Self   : in     Pyramid_Writer;
            Dice   : in out Random_Sources.Generator;
            Words  : in     Positive;
            Result :    out Texts.Wide_Text
            );

    end Calipso.Writers;
