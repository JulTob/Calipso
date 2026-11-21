--  Cuántas veces aparece cada trocito de texto.
--
--  Un fragmento es un trocito corto (unas pocas letras seguidas).
--  Toda la "memoria" del modelo de conteo es esta tabla:
--     fragmento -> número de veces que se ha visto en el corpus.

with Ada.Containers;
with Ada.Containers.Indefinite_Hashed_Maps;

with Colapso.Texts;

package Colapso.Fragment_Counts is

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
    --# El fragmento de Length símbolos que empieza en First.

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
    --# Recorre el texto y apunta todos los fragmentos de 1 a Longest letras.

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

    end Colapso.Fragment_Counts;
