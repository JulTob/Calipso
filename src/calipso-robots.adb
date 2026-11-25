with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Ada.Strings.Unbounded;
with Ada.Strings.Wide_Wide_Unbounded;

with Calipso.Web_Addresses;

package body Calipso.Robots is

    Line_Feed : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);

    Blanks : constant Ada.Strings.Maps.Character_Set :=
        Ada.Strings.Maps.To_Set (' ' & ASCII.HT & ASCII.CR);

    Longest_Pause : constant Natural := 3_600;

    type Reading is record
        Agent_Name         : Ada.Strings.Unbounded.Unbounded_String;
        Ours               : Rule_Set;
        --# The rules of the groups that name us.
        Everyones          : Rule_Set;
        --# The rules of the groups for every robot.
        Named_Us           : Boolean := False;
        Listing_Agents     : Boolean := False;
        --# True while reading the User-agent lines that open a group.
        Group_Is_Ours      : Boolean := False;
        Group_Is_Everyones : Boolean := False;
        end record;
    --# The state while reading the file line by line.

    procedure Add_Rule (
            Rules   : in out Rule_Set;
            Allowed : in     Boolean;
            Pattern : in     String
            ) is
        begin
        Rules.Patterns.Append (Pattern);
        Rules.Verdicts.Append (Allowed);
        end Add_Rule;

    function Allow_Everything return Rule_Set is
        Rules : Rule_Set;
        begin
        return Rules;
        end Allow_Everything;

    function Allow_Nothing return Rule_Set is
        Rules : Rule_Set;
        begin
        Add_Rule (Rules, False, "/");
        return Rules;
        end Allow_Nothing;

    function Trimmed (
            Text : in String
            ) return String is
        begin
        return Ada.Strings.Fixed.Trim (Text, Blanks, Blanks);
        end Trimmed;

    function Seconds_Of (
            Value : in String
            ) return Duration is
        Seconds : Natural := 0;
        begin
        for Digit of Value loop
            if Digit not in '0' .. '9' then
                return 0.0;
                end if;
            Seconds := Seconds * 10 + (Character'Pos (Digit) - Character'Pos ('0'));
            if Seconds > Longest_Pause then
                return Duration (Longest_Pause);
                end if;
            end loop;
        return Duration (Seconds);
        end Seconds_Of;
    --# A whole number of seconds. Anything else counts as 0.

    procedure Read_Agent (
            State : in out Reading;
            Value : in     String
            ) is
        Name : constant String := Web_Addresses.Lowered (Value);
        begin
        if not State.Listing_Agents then
            State.Group_Is_Ours := False;
            State.Group_Is_Everyones := False;
            --# A User-agent line after rules starts a new group.
            end if;
        State.Listing_Agents := True;
        if Name = "*" then
            State.Group_Is_Everyones := True;
        elsif Name /= "" and then Ada.Strings.Unbounded.Index (State.Agent_Name, Name) > 0 then
            State.Group_Is_Ours := True;
            State.Named_Us := True;
            end if;
        end Read_Agent;

    procedure Read_Rule (
            State   : in out Reading;
            Allowed : in     Boolean;
            Value   : in     String
            ) is
        begin
        State.Listing_Agents := False;
        if Value = "" then
            return;
            --# An empty rule forbids nothing and allows nothing new.
            end if;
        if State.Group_Is_Ours then
            Add_Rule (State.Ours, Allowed, Value);
            end if;
        if State.Group_Is_Everyones then
            Add_Rule (State.Everyones, Allowed, Value);
            end if;
        end Read_Rule;

    procedure Read_Delay (
            State : in out Reading;
            Value : in     String
            ) is
        begin
        State.Listing_Agents := False;
        if State.Group_Is_Ours then
            State.Ours.Pause := Seconds_Of (Value);
            end if;
        if State.Group_Is_Everyones then
            State.Everyones.Pause := Seconds_Of (Value);
            end if;
        end Read_Delay;

    function Without_Comment (
            Line : in String
            ) return String is
        Hash_Mark : constant Natural := Ada.Strings.Fixed.Index (Line, "#");
        begin
        if Hash_Mark = 0 then
            return Line;
            end if;
        return Line (Line'First .. Hash_Mark - 1);
        end Without_Comment;
    --# What follows # is a comment.

    procedure Read_Line (
            State : in out Reading;
            Line  : in     String
            ) is
        Bare  : constant String := Without_Comment (Line);
        Colon : constant Natural := Ada.Strings.Fixed.Index (Bare, ":");
        begin
        if Colon = 0 then
            return;
            end if;
        declare
            Field : constant String := Web_Addresses.Lowered (Trimmed (Bare (Bare'First .. Colon - 1)));
            Value : constant String := Trimmed (Bare (Colon + 1 .. Bare'Last));
            begin
            if Field = "user-agent" then
                Read_Agent (State, Value);
            elsif Field = "allow" then
                Read_Rule (State, True, Value);
            elsif Field = "disallow" then
                Read_Rule (State, False, Value);
            elsif Field = "crawl-delay" then
                Read_Delay (State, Value);
                end if;
            end;
        end Read_Line;

    function Parsed (
            Text       : in Texts.Wide_Text;
            Agent_Name : in String
            ) return Rule_Set is
        use Ada.Strings.Unbounded;
        State : Reading;
        Line  : Unbounded_String;
        Char  : Wide_Wide_Character;
        begin
        State.Agent_Name := To_Unbounded_String (Web_Addresses.Lowered (Agent_Name));
        for Position in 1 .. Ada.Strings.Wide_Wide_Unbounded.Length (Text) loop
            Char := Ada.Strings.Wide_Wide_Unbounded.Element (Text, Position);
            if Char = Line_Feed then
                Read_Line (State, To_String (Line));
                Line := Null_Unbounded_String;
            else
                Append (Line, Web_Addresses.Narrowed ((1 => Char)));
                end if;
            end loop;
        Read_Line (State, To_String (Line));
        if State.Named_Us then
            return State.Ours;
            end if;
        return State.Everyones;
        end Parsed;

    function Place_Of (
            Text  : in String;
            Piece : in String;
            From  : in Positive
            ) return Natural is
        begin
        if Piece = "" then
            return From;
            --# An empty piece is found at once, wherever we are.
            end if;
        if From > Text'Last then
            return 0;
            end if;
        return Ada.Strings.Fixed.Index (Text, Piece, From);
        end Place_Of;
    --# Where Piece is first written in Text, looking from From on. 0 if nowhere.

    function Fits (
            Pattern : in String;
            Path    : in String
            ) return Boolean is
        Must_End : constant Boolean := Pattern'Length > 0 and then Pattern (Pattern'Last) = '$';
        Last     : Natural := Pattern'Last;
        --# The last character of the pattern that is not the final $.
        Matched  : Natural := 0;
        --# How many characters of the path have been matched so far.
        Start    : Positive := Pattern'First;
        --# Where the next piece of the pattern begins.
        Star     : Natural;
        Stop     : Natural;
        Found    : Natural;
        Is_First : Boolean := True;
        Is_Last  : Boolean;
        begin
        if Must_End then
            Last := Pattern'Last - 1;
            end if;
        loop
            Star := Place_Of (Pattern (Pattern'First .. Last), "*", Start);
            Is_Last := Star = 0;
            if Is_Last then
                Stop := Last;
            else
                Stop := Star - 1;
                end if;
            declare
                Piece : constant String := Pattern (Start .. Stop);
                begin
                if Is_First then
                    if not Web_Addresses.Starts_With (Path, Piece) then
                        return False;
                        end if;
                    Matched := Piece'Length;
                elsif Is_Last and then Must_End then
                    if Path'Length - Piece'Length < Matched then
                        return False;
                        end if;
                    return Web_Addresses.Ends_With (Path, Piece);
                else
                    Found := Place_Of (Path, Piece, Path'First + Matched);
                    if Found = 0 then
                        return False;
                        end if;
                    Matched := (Found - Path'First) + Piece'Length;
                    end if;
                end;
            exit when Is_Last;
            Is_First := False;
            Start := Star + 1;
            end loop;
        if Must_End then
            return Matched = Path'Length;
            end if;
        return True;
        end Fits;

    function Allows (
            Rules : in Rule_Set;
            Path  : in String
            ) return Boolean is
        Best_Length  : Integer := -1;
        Best_Allowed : Boolean := True;
        begin
        for Index in 1 .. Natural (Rules.Patterns.Length) loop
            declare
                Pattern : constant String := Rules.Patterns.Element (Index);
                Allowed : constant Boolean := Rules.Verdicts.Element (Index);
                Longer  : constant Boolean := Pattern'Length > Best_Length;
                Kinder  : constant Boolean := Pattern'Length = Best_Length and then Allowed;
                begin
                if Fits (Pattern, Path) and then (Longer or else Kinder) then
                    Best_Length := Pattern'Length;
                    Best_Allowed := Allowed;
                    end if;
                end;
            end loop;
        return Best_Allowed;
        end Allows;

    function Delay_Of (
            Rules : in Rule_Set
            ) return Duration is
        begin
        return Rules.Pause;
        end Delay_Of;

    end Calipso.Robots;
