package body Colapso.Alphabets is

    function Size (
            Letters : in Alphabet
            ) return Symbol is
        begin
        return Letters.Used;
        end Size;

    function Is_Full (
            Letters : in Alphabet
            ) return Boolean is
        begin
        return Letters.Used = Symbol'Last;
        end Is_Full;

    function Contains (
            Letters : in Alphabet;
            Char    : in Wide_Wide_Character
            ) return Boolean is
        begin
        for Value in Symbol range 2 .. Letters.Used loop
            if Letters.Table (Value) = Char then
                return True;
                end if;
            end loop;
        return False;
        end Contains;

    procedure Include (
            Letters : in out Alphabet;
            Char    : in     Wide_Wide_Character
            ) is
        begin
        if Contains (Letters, Char) then
            return;
            end if;
        if Is_Full (Letters) then
            return;
            end if;
        Letters.Used := Letters.Used + 1;
        Letters.Table (Letters.Used) := Char;
        end Include;

    function Symbol_Of (
            Letters : in Alphabet;
            Char    : in Wide_Wide_Character
            ) return Symbol is
        begin
        for Value in Symbol range 2 .. Letters.Used loop
            if Letters.Table (Value) = Char then
                return Value;
                end if;
            end loop;
        return Unknown;
        end Symbol_Of;

    function Character_Of (
            Letters : in Alphabet;
            Value   : in Symbol
            ) return Wide_Wide_Character is
        begin
        return Letters.Table (Value);
        end Character_Of;

    end Colapso.Alphabets;
