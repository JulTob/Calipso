--  Writing from the top down, in two levels.
--
--     Level of kinds  : a canvas whose cells are KINDS of token is collapsed. This is the
--                       plan: "usual word, long word ending in -ed, comma, ..."
--     Handover        : the plan is turned into a canvas of letters. Marks and usual words
--                       are written as they are. Every other word becomes a BOX: holes
--                       that may only hold letters, with the ending of its kind written.
--     Level of letters: the letter brain fills the boxes.
--
--  The engine and the brains are the ones the flat method uses. Nothing is new but
--  the order: a decision of one level is the template of the level below.
--
--  It mirrors reference/calipso_ref/pyramids.py.

with Calipso.Alphabets;
with Calipso.Canvases;
with Calipso.Counting_Oracles;
with Calipso.Kinds;
with Calipso.Oracles;
with Calipso.Random_Sources;
with Calipso.Texts;

package Calipso.Pyramids is

    type Handover is (Spell, Pick);
    --# How a word that is not usual becomes letters:
    --#    Spell: the letter brain writes it, inside a box of the right size and ending.
    --#    Pick : a word of that kind is taken from the words seen while studying.

    Default_Longest : constant Positive := 5;
    --# The widest run of kinds the level of kinds looks at.

    type Pyramid is private;

    procedure Study (
            Self : in out Pyramid;
            Text : in     Wide_Wide_String
            );
    --# Reads the text as tokens, decides the kinds, and counts how kinds follow each other.

    function Book_Of (
            Self : in Pyramid
            ) return Kinds.Book;

    procedure Write (
            Self    : in     Pyramid;
            Speller : in     Oracles.Oracle'Class;
            Letters : in     Alphabets.Alphabet;
            Dice    : in out Random_Sources.Generator;
            Size    : in     Positive;
            Passing : in     Handover;
            Result  :    out Texts.Wide_Text
            );
    --# A text planned as Size kinds of token. Speller is the brain of the level of
    --# letters, and Letters the alphabet that brain was taught with.

    function Plain_Text (
            Board   : in Canvases.Canvas;
            Letters : in Alphabets.Alphabet
            ) return Wide_Wide_String
        with Pre => Canvases.Blank_Count (Board) = 0;
    --# The letters of a canvas with no holes left.

private

    type Pyramid is record
        Book  : Kinds.Book;
        Brain : Counting_Oracles.Counting_Oracle;
        --# The brain of the level of kinds: it counts runs of kinds, as the letter brain counts runs of letters.
        end record;

    end Calipso.Pyramids;
