--  The alphabet: the table that translates letter <-> symbol.
--
--  It is learned from the corpus: each new letter gets the next free number,
--  in order of appearance.

package Calipso.Alphabets is

    Unknown_Mark : constant Wide_Wide_Character := '?';
    --# How the unknown symbol is drawn.

    type Alphabet is private;
    --# A newly declared alphabet contains only the unknown symbol.

    function Size (
            Letters : in Alphabet
            ) return Symbol;

    function Is_Full (
            Letters : in Alphabet
            ) return Boolean;

    function Contains (
            Letters : in Alphabet;
            Char    : in Wide_Wide_Character
            ) return Boolean;

    procedure Include (
            Letters : in out Alphabet;
            Char    : in     Wide_Wide_Character
            );
    --# Adds the letter if it is new and there is room. Otherwise it does nothing:
    --# letters that do not fit will be read later as "unknown".

    function Symbol_Of (
            Letters : in Alphabet;
            Char    : in Wide_Wide_Character
            ) return Symbol
        with Post => Symbol_Of'Result <= Size (Letters);

    function Character_Of (
            Letters : in Alphabet;
            Value   : in Symbol
            ) return Wide_Wide_Character
        with Pre => Value <= Size (Letters);

    function Common_Letters return Alphabet;
    --# A ready-made alphabet for western text, for when the text is not known beforehand.

private

    type Character_Table is array (Symbol) of Wide_Wide_Character;

    type Alphabet is record
        Used  : Symbol := 1;
        Table : Character_Table := (others => Unknown_Mark);
        end record;

    end Calipso.Alphabets;
