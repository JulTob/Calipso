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

    function Check_Of (
            Piece : in Fragment
            ) return Ada.Containers.Hash_Type;
    --# A second scrambled number, different from Hash: the "check number" of a fragment.

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
    --#
    --# With bounded memory each fragment has ONE counter where it may live,
    --# chosen by its scrambled number. The counter also keeps the check number
    --# of its owner, so that a fragment never seen is not mistaken for the
    --# owner: it reads as 0, as it should.
    --#
    --# When a newcomer finds its counter taken by another fragment, it knocks
    --# one off the owner's count; when that count reaches 0 the newcomer takes
    --# the counter. So what is seen often stays, and what was seen once, long
    --# ago, makes room: the memory forgets instead of filling up.

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

    package Check_Vectors is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Ada.Containers.Hash_Type,
            "="          => Ada.Containers."="
            );

    type Count_Table is record
        Counts   : Count_Maps.Map;
        --# Exact memory: fragment -> times seen.
        Capacity : Natural := 0;
        Slots    : Slot_Vectors.Vector;
        --# Bounded memory: the count kept in each counter.
        Checks   : Check_Vectors.Vector;
        --# Bounded memory: the check number of the fragment each counter belongs to.
        end record;

    end Calipso.Fragment_Counts;
