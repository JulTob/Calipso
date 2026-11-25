package body Calipso.Alphabets is

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

    type Number_List is array (Positive range <>) of Natural;

    Line_Feed_Number    : constant Natural := 10;
    First_Basic_Number  : constant Natural := 32;
    Last_Basic_Number   : constant Natural := 126;
    --# From the space to the tilde: A-Z a-z 0-9 and punctuation.

    Other_Letter_Numbers : constant Number_List := (
        225, 233, 237, 243, 250, 252, 241, 193, 201, 205, 211, 218, 220, 209, 191, 161,
        --# Spanish: accented vowels, u with dots, n with tilde, opening question and exclamation marks.
        224, 232, 236, 242, 249, 226, 234, 238, 244, 251, 228, 235, 239, 246, 231, 227, 245, 223,
        --# Other accented letters of western Europe.
        8211, 8212, 8216, 8217, 8220, 8221, 8230, 171, 187, 8364, 183, 186, 170
        --# Printing marks: dashes, curly quotes, three dots, angle quotes, euro, middle dot, ordinals.
        );
    --# Each letter by its Unicode number, so that this file needs nothing but plain characters.

    function Common_Letters return Alphabet is
        Letters : Alphabet;
        begin
        Include (Letters, Wide_Wide_Character'Val (Line_Feed_Number));
        for Number in First_Basic_Number .. Last_Basic_Number loop
            Include (Letters, Wide_Wide_Character'Val (Number));
            end loop;
        for Number of Other_Letter_Numbers loop
            Include (Letters, Wide_Wide_Character'Val (Number));
            end loop;
        return Letters;
        end Common_Letters;

    end Calipso.Alphabets;
