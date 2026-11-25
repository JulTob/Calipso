--  The kinds of token ("syntokens").
--
--  The upper level of the pyramid does not see letters. It sees KINDS:
--
--     a mark is its own kind                         "."  ","
--     a number is known by how many digits it has    1, 2, 3, 4 or more
--     a very usual word is its own kind              "the"  "of"
--     any other word is known by its SHAPE:
--         does it start with a capital? how long is it? how does it end?
--
--  A kind is a Symbol, like a letter is: the same brains and the same collapse
--  engine work on both. The Book is the table token <-> kind. It is decided by
--  reading a text once.
--
--  It mirrors reference/calipso_ref/kinds.py.

with Calipso.Random_Sources;
with Calipso.Texts;
with Calipso.Tokens;

private with Ada.Containers.Indefinite_Hashed_Maps;
private with Ada.Containers.Vectors;
private with Ada.Strings.Wide_Wide_Hash;

package Calipso.Kinds is

    Most_Marks           : constant := 40;
    Most_Words           : constant := 120;
    Most_Endings         : constant := 10;
    Ending_Length        : constant := 2;
    Shortest_With_Ending : constant := 4;
    Size_Groups          : constant := 4;
    Number_Kinds         : constant := 4;
    --# 1 + 40 + 4 + 120 + 2 * 4 * (10 + 1) = 253 kinds at most: they fit in a Symbol.

    type Kind_Family is (Unknown_Kind, Mark_Kind, Number_Kind, Word_Kind, Shape_Kind);

    type Book is private;

    function Built (
            Sample : in Tokens.Token_List
            ) return Book;
    --# Reads a text once and decides the kinds.

    function Kind_Count (
            Self : in Book
            ) return Symbol;

    function Kind_Of (
            Self  : in Book;
            Token : in Wide_Wide_String
            ) return Symbol
        with
            Pre  => Token'Length >= 1,
            Post => Kind_Of'Result <= Kind_Count (Self);
    --# The kind of any token, seen before or not. Unknown only for a mark never seen.

    function Family_Of (
            Self : in Book;
            Kind : in Symbol
            ) return Kind_Family
        with Pre => Kind <= Kind_Count (Self);

    function Text_Of (
            Self : in Book;
            Kind : in Symbol
            ) return Wide_Wide_String
        with Pre => Kind <= Kind_Count (Self);
    --# The mark, the usual word, or the ending of a shape ("" for a shape with no usual ending).

    function Figures_Of (
            Self : in Book;
            Kind : in Symbol
            ) return Natural
        with Pre => Kind <= Kind_Count (Self);
    --# How many digits a number of this kind has.

    function Is_Capital (
            Self : in Book;
            Kind : in Symbol
            ) return Boolean
        with Pre => Kind <= Kind_Count (Self);

    function Has_Members (
            Self : in Book;
            Kind : in Symbol
            ) return Boolean
        with Pre => Kind <= Kind_Count (Self);
    --# Was any word seen in this shape?

    procedure Draw_Member (
            Self  : in     Book;
            Kind  : in     Symbol;
            Dice  : in out Random_Sources.Generator;
            Drawn :    out Texts.Wide_Text
            )
        with Pre => Kind <= Kind_Count (Self) and then Has_Members (Self, Kind);
    --# One of the words seen in this kind. A word seen twice as often comes out twice as often.

private

    type Kind_Note is record
        Family  : Kind_Family := Unknown_Kind;
        Text    : Texts.Wide_Text;
        Figures : Natural := 0;
        Capital : Boolean := False;
        Group   : Natural := 0;
        end record;
    --# What one kind is.

    type Note_Array is array (Symbol) of Kind_Note;

    package Kind_Maps is new Ada.Containers.Indefinite_Hashed_Maps (
            Key_Type        => Wide_Wide_String,
            Element_Type    => Symbol,
            Hash            => Ada.Strings.Wide_Wide_Hash,
            Equivalent_Keys => "="
            );

    package Place_Maps is new Ada.Containers.Indefinite_Hashed_Maps (
            Key_Type        => Wide_Wide_String,
            Element_Type    => Positive,
            Hash            => Ada.Strings.Wide_Wide_Hash,
            Equivalent_Keys => "="
            );

    type Kind_Member is record
        Word : Texts.Wide_Text;
        Seen : Positive := 1;
        end record;

    package Member_Vectors is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Kind_Member
            );

    type Member_Lists is array (Symbol) of Member_Vectors.Vector;

    type Total_Array is array (Symbol) of Natural;

    type Book is record
        Used         : Symbol := Unknown;
        --# Kinds 1 .. Used exist. Kind 1 is "unknown".
        Notes        : Note_Array;
        By_Text      : Kind_Maps.Map;
        --# Marks and usual words: the token is the key.
        Ending_Place : Place_Maps.Map;
        --# The usual endings, numbered from 1.
        First_Number : Symbol := Unknown;
        First_Shape  : Symbol := Unknown;
        Members      : Member_Lists;
        Totals       : Total_Array := (others => 0);
        --# Totals (K): how many times a word of shape K was seen, all its members together.
        end record;

    end Calipso.Kinds;
