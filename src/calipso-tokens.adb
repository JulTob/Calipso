with Ada.Wide_Wide_Characters.Handling;

package body Calipso.Tokens is

    Last_Blank_Code     : constant := 32;
    No_Break_Space_Code : constant := 160;
    Feeds_In_A_Break    : constant := 2;

    function Is_Letter (
            Char : in Wide_Wide_Character
            ) return Boolean is
        begin
        return Ada.Wide_Wide_Characters.Handling.Is_Letter (Char);
        end Is_Letter;

    function Is_Digit (
            Char : in Wide_Wide_Character
            ) return Boolean is
        begin
        return Char in '0' .. '9';
        end Is_Digit;

    function Is_Blank (
            Char : in Wide_Wide_Character
            ) return Boolean is
        Code : constant Natural := Wide_Wide_Character'Pos (Char);
        begin
        return Code <= Last_Blank_Code or else Code = No_Break_Space_Code;
        end Is_Blank;

    function Sort_Of (
            Token : in Wide_Wide_String
            ) return Token_Sort is
        First : constant Wide_Wide_Character := Token (Token'First);
        begin
        if Is_Letter (First) then
            return Word;
            end if;
        if Is_Digit (First) then
            return Number;
            end if;
        if First = Line_Feed then
            return Break;
            end if;
        return Mark;
        end Sort_Of;

    function Run_End (
            Text    : in Wide_Wide_String;
            Start   : in Positive;
            Belongs : not null access function (Char : in Wide_Wide_Character) return Boolean
            ) return Positive is
        Last : Positive := Start;
        begin
        while Last < Text'Last and then Belongs (Text (Last + 1)) loop
            Last := Last + 1;
            end loop;
        return Last;
        end Run_End;
    --# The last position of the run of characters of one sort that begins at Start.

    function Feeds_In (
            Text  : in Wide_Wide_String;
            First : in Positive;
            Last  : in Positive
            ) return Natural is
        Count : Natural := 0;
        begin
        for Position in First .. Last loop
            if Text (Position) = Line_Feed then
                Count := Count + 1;
                end if;
            end loop;
        return Count;
        end Feeds_In;
    --# How many line feeds there are from First to Last.

    function Split (
            Text : in Wide_Wide_String
            ) return Token_List is
        Found    : Token_List;
        Position : Positive := Text'First;
        Last     : Positive;
        Char     : Wide_Wide_Character;
        begin
        while Position <= Text'Last loop
            Char := Text (Position);
            if Is_Letter (Char) then
                Last := Run_End (Text, Position, Is_Letter'Access);
                Found.Append (Text (Position .. Last));
            elsif Is_Digit (Char) then
                Last := Run_End (Text, Position, Is_Digit'Access);
                Found.Append (Text (Position .. Last));
            elsif Is_Blank (Char) then
                Last := Run_End (Text, Position, Is_Blank'Access);
                if Feeds_In (Text, Position, Last) >= Feeds_In_A_Break then
                    Found.Append (Break_Text);
                    end if;
            else
                Last := Position;
                Found.Append (Text (Position .. Position));
                end if;
            Position := Last + 1;
            end loop;
        return Found;
        end Split;

    end Calipso.Tokens;
