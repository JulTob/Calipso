--  How many times each small piece of text appears.
--
--  A fragment is a short piece (a few letters in a row).
--  The whole "memory" of the counting model is this table:
--     fragment -> number of times it was seen in the corpus.
--
--  The table has two modes: exact memory (grows with the text) and bounded
--  memory (a fixed size, chosen by whoever uses it).

with Ada.Containers;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;

with Calipso.Records;
with Calipso.Texts;

package Calipso.Fragment_Counts is

    type Fragment is array (Positive range <>) of Symbol;

    function Hash (
            Piece : in Fragment
            ) return Ada.Containers.Hash_Type;

    function Slice (
            Text   : in Texts.Symbol_Text;
            First  : in Positive;
            Length : in Natural
            ) return Fragment
        with Pre => First + Length - 1 <= Text.Last_Index;
    --# The fragment of Length symbols that starts at First.

    type Count_Table is private;
    --# A newly declared table has exact memory: it grows with the text.

    procedure Limit (
            Table    : in out Count_Table;
            Capacity : in     Natural
            );
    --# Empties the table and fixes its size. 0 = exact memory. More than 0 =
    --# bounded memory: a fixed number of counters, however much text is read.
    --# Fragments that land on the same counter share it: counts can only be
    --# too high, never too low.

    function Capacity_Of (
            Table : in Count_Table
            ) return Natural;

    procedure Add_One (
            Table : in out Count_Table;
            Piece : in     Fragment
            );

    function Count_Of (
            Table : in Count_Table;
            Piece : in Fragment
            ) return Natural;

    function Distinct_Fragments (
            Table : in Count_Table
            ) return Natural;

    procedure Learn (
            Table   : in out Count_Table;
            Text    : in     Texts.Symbol_Text;
            Longest : in     Positive
            );
    --# Walks the text and notes every fragment from 1 to Longest letters.

    procedure Save (
            Table : in     Count_Table;
            Tape  : in out Records.Tape
            );
    --# Bounded memory: the counters in use, each with its place.
    --# Exact memory: every fragment (its length, its symbols) and its count.

    procedure Load (
            Table : in out Count_Table;
            Tape  : in out Records.Tape
            );

private

    package Count_Maps is new Ada.Containers.Indefinite_Hashed_Maps (
            Key_Type        => Fragment,
            Element_Type    => Natural,
            Hash            => Hash,
            Equivalent_Keys => "="
            );

    package Slot_Vectors is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Natural
            );

    type Count_Table is record
        Counts   : Count_Maps.Map;
        Capacity : Natural := 0;
        Slots    : Slot_Vectors.Vector;
        end record;

    end Calipso.Fragment_Counts;
