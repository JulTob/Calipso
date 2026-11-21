--  El alfabeto: la tabla que traduce letra <-> símbolo.
--
--  Se aprende del corpus: cada letra nueva recibe el siguiente número libre,
--  por orden de aparición.

package Colapso.Alphabets is

    Unknown_Mark : constant Wide_Wide_Character := '?';
    --# Cómo se pinta el símbolo desconocido.

    type Alphabet is private;
    --# Un alfabeto recién declarado solo contiene el símbolo desconocido.

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
    --# Añade la letra si es nueva y queda sitio. Si no, no hace nada:
    --# las letras que no caben se leerán después como "desconocida".

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

private

    type Character_Table is array (Symbol) of Wide_Wide_Character;

    type Alphabet is record
        Used  : Symbol := 1;
        Table : Character_Table := (others => Unknown_Mark);
        end record;

    end Colapso.Alphabets;
