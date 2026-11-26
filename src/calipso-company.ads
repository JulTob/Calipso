--  A word described by the company it keeps.
--
--  For every word, count what stands around it: one count for each (distance,
--  side, neighbour). That list of counts is the word's vector. Two words that
--  keep the same company get vectors that point the same way.
--
--  The settings decide what "company" means:
--
--     Reach       how many tokens are looked at on each side (1 = the nearest only)
--     Context     As_Kinds: a neighbour counts as its KIND (usual words as themselves,
--                 the others by shape). Coarse: it finds grammar.
--                 As_Words: a neighbour counts as the WORD it is, hashed into a fixed
--                 number of buckets. Fine: it finds groups like "things that eat grass".
--     Fold_Case   "Zebras" and "zebras" are one word
--     Every_Word  False: words that are already their own kind are left out
--     Soften      counts are passed through log (1 + count) and the vector is made
--                 of length 1, so that very usual neighbours do not drown the rest
--
--  The first half of a vector is what stands BEFORE the word and the second half
--  what stands AFTER it: the two halves the complex product needs.
--
--  It mirrors reference/calipso_ref/company.py.

with Calipso.Kinds;
with Calipso.Tokens;
with Calipso.Vectors;

private with Ada.Containers.Indefinite_Hashed_Maps;
private with Ada.Containers.Indefinite_Vectors;
private with Ada.Containers.Vectors;
private with Ada.Strings.Wide_Wide_Hash;

package Calipso.Company is

    type Context_Sort is (As_Kinds, As_Words);

    Default_Buckets : constant Positive := 256;

    type Settings is record
        Reach      : Positive := 1;
        Context    : Context_Sort := As_Kinds;
        Buckets    : Positive := Default_Buckets;
        Fold_Case  : Boolean := True;
        Every_Word : Boolean := False;
        Soften     : Boolean := True;
        end record;

    type Hash_Number is mod 2 ** 32;

    function Hash_Of (
            Text : in Wide_Wide_String
            ) return Hash_Number;
    --# A scrambled number for a word (FNV-1a over its characters).

    type Table is private;

    function Built (
            Sample  : in Tokens.Token_List;
            Book    : in Kinds.Book;
            Options : in Settings
            ) return Table;
    --# Book tells the kind of each token: it decides which words are left out and,
    --# with As_Kinds, what a neighbour counts as.

    function Row_Count (
            Self : in Table
            ) return Natural;

    function Has_Word (
            Self : in Table;
            Word : in Wide_Wide_String
            ) return Boolean;

    function Row_Of (
            Self : in Table;
            Word : in Wide_Wide_String
            ) return Positive
        with Pre => Has_Word (Self, Word);

    function Vector_At (
            Self : in Table;
            Row  : in Positive
            ) return Vectors.Vector
        with Pre => Row <= Row_Count (Self);

    function Word_At (
            Self : in Table;
            Row  : in Positive
            ) return Wide_Wide_String
        with Pre => Row <= Row_Count (Self);

    function Seen_At (
            Self : in Table;
            Row  : in Positive
            ) return Natural
        with Pre => Row <= Row_Count (Self);
    --# How many times the word of this row was met.

    function Vector_Of (
            Self : in Table;
            Word : in Wide_Wide_String
            ) return Vectors.Vector
        with Pre => Has_Word (Self, Word);

    function Rows_Of (
            Self : in Table
            ) return Vectors.Vector_List;
    --# Every vector, in the order of the rows.

private

    package Row_Maps is new Ada.Containers.Indefinite_Hashed_Maps (
            Key_Type        => Wide_Wide_String,
            Element_Type    => Positive,
            Hash            => Ada.Strings.Wide_Wide_Hash,
            Equivalent_Keys => "="
            );

    package Word_Lists is new Ada.Containers.Indefinite_Vectors (
            Index_Type   => Positive,
            Element_Type => Wide_Wide_String
            );

    package Count_Lists is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Natural
            );

    type Table is record
        Options : Settings;
        Size    : Natural := 0;
        --# How many different neighbours can be told apart at one distance on one side.
        Words   : Word_Lists.Vector;
        Places  : Row_Maps.Map;
        Rows    : Vectors.Vector_List;
        Seen    : Count_Lists.Vector;
        end record;

    end Calipso.Company;
