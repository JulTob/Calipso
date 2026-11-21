--  How many times each small piece of text appears.
--
--  A fragment is a short piece (a few letters in a row).
--  The whole "memory" of the counting model is this table:
--     fragment -> number of times it was seen in the corpus.

with Ada.Containers;
with Ada.Containers.Indefinite_Hashed_Maps;

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

private

    package Count_Maps is new Ada.Containers.Indefinite_Hashed_Maps (
            Key_Type        => Fragment,
            Element_Type    => Natural,
            Hash            => Hash,
            Equivalent_Keys => "="
            );

    type Count_Table is record
        Counts : Count_Maps.Map;
        end record;

    end Calipso.Fragment_Counts;
