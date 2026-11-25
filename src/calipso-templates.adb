with Ada.Strings.Wide_Wide_Unbounded;

package body Calipso.Templates is

    Escape_Mark     : constant Wide_Wide_Character := '\';
    New_Line_Letter : constant Wide_Wide_Character := 'n';
    Line_Feed       : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);
    Ellipsis        : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2026#);
    --# The ellipsis character, in case the template has it instead of three dots.
    Three_Dots      : constant Wide_Wide_String := "...";

    function Is_Digit (
            Char : in Wide_Wide_Character
            ) return Boolean is
        begin
        return Char in '0' .. '9';
        end Is_Digit;

    function Number_In (
            Inside : in Wide_Wide_String
            ) return Natural is
        Value : Natural := 0;
        Digit : Natural;
        begin
        if Inside'Length = 0 then
            return 0;
            end if;
        for Char of Inside loop
            if not Is_Digit (Char) then
                return 0;
                end if;
            Digit := Wide_Wide_Character'Pos (Char) - Wide_Wide_Character'Pos ('0');
            Value := Value * 10 + Digit;
            if Value > Largest_Hole then
                return 0;
                end if;
            end loop;
        return Value;
        end Number_In;
    --# Turns "25" into 25. Returns 0 if it is not only digits or if it is too large.

    function Hole_Size (
            Inside : in Wide_Wide_String
            ) return Natural is
        begin
        if Inside = Three_Dots then
            return Default_Hole;
            end if;
        if Inside'Length = 1 and then Inside (Inside'First) = Ellipsis then
            return Default_Hole;
            end if;
        return Number_In (Inside);
        end Hole_Size;
    --# Size of the hole described by the text between brackets. 0 = it is not a hole.

    function Closing_Of (
            Template : in Wide_Wide_String;
            Opening  : in Positive
            ) return Natural is
        begin
        for Position in Opening + 1 .. Template'Last loop
            if Template (Position) = Hole_Closing then
                return Position;
                end if;
            end loop;
        return 0;
        end Closing_Of;
    --# Position of the closing bracket. 0 if there is none.

    procedure Append_Blanks (
            Board : in out Canvases.Canvas;
            Count : in     Natural
            ) is
        begin
        for Repetition in 1 .. Count loop
            Canvases.Append_Blank (Board);
            end loop;
        end Append_Blanks;

    procedure Append_Letter (
            Board   : in out Canvases.Canvas;
            Letters : in     Alphabets.Alphabet;
            Char    : in     Wide_Wide_Character
            ) is
        Value : constant Symbol := Alphabets.Symbol_Of (Letters, Char);
        begin
        Canvases.Append_Given (Board, Value);
        end Append_Letter;

    function Is_New_Line_Escape (
            Template : in Wide_Wide_String;
            Position : in Positive
            ) return Boolean is
        begin
        if Template (Position) /= Escape_Mark then
            return False;
            end if;
        if Position + 1 > Template'Last then
            return False;
            end if;
        return Template (Position + 1) = New_Line_Letter;
        end Is_New_Line_Escape;

    function Parsed (
            Template : in Wide_Wide_String;
            Letters  : in Alphabets.Alphabet
            ) return Canvases.Canvas is
        Board    : Canvases.Canvas;
        Position : Positive := Template'First;
        Closing  : Natural;
        Size     : Natural;
        begin
        while Position <= Template'Last loop
            Closing := 0;
            Size := 0;
            if Template (Position) = Hole_Opening then
                Closing := Closing_Of (Template, Position);
                end if;
            if Closing > 0 then
                Size := Hole_Size (Template (Position + 1 .. Closing - 1));
                end if;
            if Size > 0 then
                Append_Blanks (Board, Size);
                Position := Closing + 1;
            elsif Template (Position) = Blank_Mark then
                Canvases.Append_Blank (Board);
                Position := Position + 1;
            elsif Is_New_Line_Escape (Template, Position) then
                Append_Letter (Board, Letters, Line_Feed);
                Position := Position + 2;
            else
                Append_Letter (Board, Letters, Template (Position));
                Position := Position + 1;
                end if;
            end loop;
        return Board;
        end Parsed;

    function From_Text (
            Text   : in Texts.Symbol_Text;
            First  : in Positive;
            Length : in Natural
            ) return Canvases.Canvas is
        Board : Canvases.Canvas;
        begin
        for Position in First .. First + Length - 1 loop
            Canvases.Append_Given (Board, Text.Element (Position));
            end loop;
        return Board;
        end From_Text;

    function Is_Model_Cell (
            Board    : in Canvases.Canvas;
            Position : in Integer
            ) return Boolean is
        use type Canvases.Cell_State;
        begin
        if Position < 1 then
            return False;
            end if;
        if Position > Canvases.Length (Board) then
            return False;
            end if;
        return Canvases.State_At (Board, Position) /= Canvases.Given;
        end Is_Model_Cell;
    --# Is this a cell the person did NOT give (a hole or a decided letter)?

    function Rendered (
            Board        : in Canvases.Canvas;
            Letters      : in Alphabets.Alphabet;
            Mark_Guesses : in Boolean := False
            ) return Wide_Wide_String is
        use Ada.Strings.Wide_Wide_Unbounded;
        Plain           : Unbounded_Wide_Wide_String;
        Is_Model        : Boolean;
        Before_Is_Model : Boolean;
        After_Is_Model  : Boolean;
        Value           : Symbol;
        begin
        for Position in 1 .. Canvases.Length (Board) loop
            Is_Model := Is_Model_Cell (Board, Position);
            Before_Is_Model := Is_Model_Cell (Board, Position - 1);
            After_Is_Model := Is_Model_Cell (Board, Position + 1);
            if Mark_Guesses and then Is_Model and then not Before_Is_Model then
                Append (Plain, Hole_Opening);
                end if;
            if Canvases.Is_Blank (Board, Position) then
                Append (Plain, Blank_Mark);
            else
                Value := Canvases.Symbol_At (Board, Position);
                Append (Plain, Alphabets.Character_Of (Letters, Value));
                end if;
            if Mark_Guesses and then Is_Model and then not After_Is_Model then
                Append (Plain, Hole_Closing);
                end if;
            end loop;
        return To_Wide_Wide_String (Plain);
        end Rendered;

    end Calipso.Templates;
