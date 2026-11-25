with Ada.Strings;
with Ada.Strings.Wide_Wide_Fixed;
with Ada.Strings.Wide_Wide_Unbounded;

package body Calipso.Pages is

    use Ada.Strings.Wide_Wide_Unbounded;

    subtype Wide_Text is Texts.Wide_Text;

    Block_Tags : constant Wide_Wide_String :=
        " p br div li ul ol h1 h2 h3 h4 h5 h6 tr table section article header footer nav aside"
        & " blockquote pre title hr dt dd form body head ";
    --# Tags that start a new paragraph. Written with a space around each name,
    --# so that looking for " p " can never find a piece of another name.

    Line_Feed      : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);
    Tab            : constant Wide_Wide_Character := Wide_Wide_Character'Val (9);
    Return_Mark    : constant Wide_Wide_Character := Wide_Wide_Character'Val (13);
    Form_Feed      : constant Wide_Wide_Character := Wide_Wide_Character'Val (12);
    No_Break_Space : constant Wide_Wide_Character := Wide_Wide_Character'Val (160);
    Double_Quote   : constant Wide_Wide_Character := '"';
    Single_Quote   : constant Wide_Wide_Character := ''';

    Largest_Letter : constant Natural := 1_114_111;
    Entity_Reach   : constant Positive := 10;
    --# An entity like &amp; is never longer than this.
    Not_A_Digit    : constant Natural := 16;

    type Scan is record
        Markup    : Wide_Text;
        Position  : Positive := 1;
        Paragraph : Wide_Text;
        Content   : Page_Content;
        end record;
    --# The state of one reading: where we are, and what has been gathered.

    function Lowered_Letter (
            Char : in Wide_Wide_Character
            ) return Wide_Wide_Character is
        begin
        if Char in 'A' .. 'Z' then
            return Wide_Wide_Character'Val (Wide_Wide_Character'Pos (Char) + 32);
            end if;
        return Char;
        end Lowered_Letter;

    function Is_Space (
            Char : in Wide_Wide_Character
            ) return Boolean is
        begin
        return Char = ' ' or else Char = Tab or else Char = Line_Feed
            or else Char = Return_Mark or else Char = Form_Feed or else Char = No_Break_Space;
        end Is_Space;

    function Matches_At (
            Text     : in Wide_Text;
            Position : in Positive;
            Word     : in Wide_Wide_String
            ) return Boolean is
        Place : Positive := Position;
        begin
        if Position + Word'Length - 1 > Length (Text) then
            return False;
            end if;
        for Char of Word loop
            if Lowered_Letter (Element (Text, Place)) /= Char then
                return False;
                end if;
            Place := Place + 1;
            end loop;
        return True;
        end Matches_At;
    --# Is Word written at this position? Capital letters count as small ones.

    function Found_At (
            Text  : in Wide_Text;
            Word  : in Wide_Wide_String;
            Start : in Positive
            ) return Natural is
        begin
        for Position in Start .. Length (Text) - Word'Length + 1 loop
            if Matches_At (Text, Position, Word) then
                return Position;
                end if;
            end loop;
        return 0;
        end Found_At;
    --# The first position, from Start on, where Word is written. 0 if nowhere.

    function Mark_At (
            Text  : in Wide_Text;
            Mark  : in Wide_Wide_Character;
            Start : in Positive;
            Limit : in Natural
            ) return Natural is
        begin
        for Position in Start .. Limit loop
            if Element (Text, Position) = Mark then
                return Position;
                end if;
            end loop;
        return 0;
        end Mark_At;
    --# The first position from Start to Limit where this character is. 0 if nowhere.

    procedure Close_Paragraph (
            State : in out Scan
            ) is
        Trimmed : constant Wide_Text := Trim (State.Paragraph, Ada.Strings.Both);
        begin
        if Length (Trimmed) > 0 then
            State.Content.Blocks.Append ((Kind => Words, Text => Trimmed));
            end if;
        State.Paragraph := Null_Unbounded_Wide_Wide_String;
        end Close_Paragraph;

    procedure Add_Letter (
            State : in out Scan;
            Char  : in     Wide_Wide_Character
            ) is
        Size : constant Natural := Length (State.Paragraph);
        begin
        if not Is_Space (Char) then
            Append (State.Paragraph, Char);
            return;
            end if;
        if Size = 0 then
            return;
            end if;
        if Element (State.Paragraph, Size) = ' ' then
            return;
            end if;
        Append (State.Paragraph, ' ');
        end Add_Letter;
    --# Any run of spaces and line breaks counts as one space.

    function Digit_Value (
            Digit : in Wide_Wide_Character
            ) return Natural is
        begin
        if Digit in '0' .. '9' then
            return Wide_Wide_Character'Pos (Digit) - Wide_Wide_Character'Pos ('0');
            end if;
        if Digit in 'a' .. 'f' then
            return Wide_Wide_Character'Pos (Digit) - Wide_Wide_Character'Pos ('a') + 10;
            end if;
        if Digit in 'A' .. 'F' then
            return Wide_Wide_Character'Pos (Digit) - Wide_Wide_Character'Pos ('A') + 10;
            end if;
        return Not_A_Digit;
        end Digit_Value;

    function Number_Value (
            Figures : in Wide_Wide_String;
            Base    : in Positive
            ) return Natural is
        Value : Natural := 0;
        Place : Natural;
        begin
        for Digit of Figures loop
            Place := Digit_Value (Digit);
            if Place >= Base then
                return 0;
                end if;
            Value := Value * Base + Place;
            if Value > Largest_Letter then
                return 0;
                end if;
            end loop;
        if Value in 55_296 .. 57_343 then
            return 0;
            --# These numbers are not letters (they are halves of a pair).
            end if;
        return Value;
        end Number_Value;
    --# The number written with these figures, if it is the number of a letter. 0 if not.

    function Entity_Number (
            Name : in Wide_Wide_String
            ) return Natural is
        begin
        if Name = "amp" then
            return Wide_Wide_Character'Pos ('&');
            end if;
        if Name = "lt" then
            return Wide_Wide_Character'Pos ('<');
            end if;
        if Name = "gt" then
            return Wide_Wide_Character'Pos ('>');
            end if;
        if Name = "quot" then
            return Wide_Wide_Character'Pos (Double_Quote);
            end if;
        if Name = "apos" then
            return Wide_Wide_Character'Pos (Single_Quote);
            end if;
        if Name = "nbsp" then
            return Wide_Wide_Character'Pos (' ');
            end if;
        if Name'Length >= 2 and then Name (Name'First) = '#'
                and then Lowered_Letter (Name (Name'First + 1)) = 'x' then
            return Number_Value (Name (Name'First + 2 .. Name'Last), 16);
            end if;
        if Name'Length >= 1 and then Name (Name'First) = '#' then
            return Number_Value (Name (Name'First + 1 .. Name'Last), 10);
            end if;
        return 0;
        end Entity_Number;
    --# The number of the letter this name stands for: "amp" -> the number of &. 0 if not known.

    procedure Read_Entity (
            State : in out Scan
            ) is
        Limit  : constant Natural := Natural'Min (Length (State.Markup), State.Position + Entity_Reach - 1);
        Stop   : constant Natural := Mark_At (State.Markup, ';', State.Position, Limit);
        Number : Natural := 0;
        begin
        if Stop > 0 then
            Number := Entity_Number (Slice (State.Markup, State.Position + 1, Stop - 1));
            end if;
        if Number = 0 then
            Add_Letter (State, '&');
            State.Position := State.Position + 1;
            return;
            end if;
        Add_Letter (State, Wide_Wide_Character'Val (Number));
        State.Position := Stop + 1;
        end Read_Entity;
    --# At an "&": a letter written by name, like &amp; or &#233;

    function Starts_With_Slash (
            Inside : in Wide_Text
            ) return Boolean is
        begin
        if Length (Inside) = 0 then
            return False;
            end if;
        return Element (Inside, 1) = '/';
        end Starts_With_Slash;

    function Tag_Name (
            Inside : in Wide_Text
            ) return Wide_Wide_String is
        Name  : Wide_Text;
        Start : Positive := 1;
        Char  : Wide_Wide_Character;
        begin
        if Starts_With_Slash (Inside) then
            Start := 2;
            end if;
        for Position in Start .. Length (Inside) loop
            Char := Lowered_Letter (Element (Inside, Position));
            exit when Char not in 'a' .. 'z' and then Char not in '0' .. '9';
            Append (Name, Char);
            end loop;
        return To_Wide_Wide_String (Name);
        end Tag_Name;
    --# "/DIV class=x" -> "div"

    function Is_Block_Tag (
            Name : in Wide_Wide_String
            ) return Boolean is
        begin
        if Name = "" then
            return False;
            end if;
        return Ada.Strings.Wide_Wide_Fixed.Index (Block_Tags, " " & Name & " ") > 0;
        end Is_Block_Tag;

    function Without_Amp (
            Value : in Wide_Wide_String
            ) return Wide_Wide_String is
        Written  : constant Wide_Wide_String := "&amp;";
        Result   : Wide_Text;
        Position : Positive := Value'First;
        begin
        while Position <= Value'Last loop
            if Position + Written'Length - 1 <= Value'Last
                    and then Value (Position .. Position + Written'Length - 1) = Written then
                Append (Result, '&');
                Position := Position + Written'Length;
            else
                Append (Result, Value (Position));
                Position := Position + 1;
                end if;
            end loop;
        return To_Wide_Wide_String (Result);
        end Without_Amp;
    --# Inside an address, & is often written &amp;

    function Value_From (
            Inside : in Wide_Text;
            Start  : in Positive
            ) return Wide_Wide_String is
        Size  : constant Natural := Length (Inside);
        Quote : Wide_Wide_Character;
        Stop  : Natural;
        begin
        if Start > Size then
            return "";
            end if;
        Quote := Element (Inside, Start);
        if Quote = Double_Quote or else Quote = Single_Quote then
            Stop := Mark_At (Inside, Quote, Start + 1, Size);
            if Stop = 0 then
                Stop := Size + 1;
                end if;
            return Slice (Inside, Start + 1, Stop - 1);
            end if;
        Stop := Start;
        while Stop <= Size and then not Is_Space (Element (Inside, Stop)) loop
            Stop := Stop + 1;
            end loop;
        return Slice (Inside, Start, Stop - 1);
        end Value_From;
    --# The value that starts at this position: up to the matching quote, or up to the next space.

    function After_Spaces (
            Inside : in Wide_Text;
            Start  : in Positive
            ) return Positive is
        Position : Positive := Start;
        begin
        while Position <= Length (Inside) and then Is_Space (Element (Inside, Position)) loop
            Position := Position + 1;
            end loop;
        return Position;
        end After_Spaces;
    --# The first position, from Start on, that does not hold a space.

    function Attribute (
            Inside : in Wide_Text;
            Name   : in Wide_Wide_String
            ) return Wide_Wide_String is
        Size        : constant Natural := Length (Inside);
        Position    : Natural := Found_At (Inside, Name, 2);
        After       : Positive;
        Starts_Word : Boolean;
        begin
        while Position > 0 loop
            After := After_Spaces (Inside, Position + Name'Length);
            Starts_Word := Is_Space (Element (Inside, Position - 1));
            if Starts_Word and then After <= Size and then Element (Inside, After) = '=' then
                After := After_Spaces (Inside, After + 1);
                return Without_Amp (Value_From (Inside, After));
                end if;
            Position := Found_At (Inside, Name, Position + 1);
            end loop;
        return "";
        end Attribute;
    --# The value of name="value" inside a tag. "" if it is not there.

    procedure Skip_Past_Closing (
            State : in out Scan;
            Name  : in     Wide_Wide_String
            ) is
        Size    : constant Natural := Length (State.Markup);
        Closing : constant Natural := Found_At (State.Markup, "</" & Name, State.Position);
        Stop    : Natural := 0;
        begin
        if Closing > 0 then
            Stop := Mark_At (State.Markup, '>', Closing, Size);
            end if;
        if Stop = 0 then
            State.Position := Size + 1;
        else
            State.Position := Stop + 1;
            end if;
        end Skip_Past_Closing;
    --# Jumps to just after </name>. If it never closes, to the end of the page.

    procedure Add_Media (
            State   : in out Scan;
            Kind    : in     Block_Kind;
            Address : in     Wide_Wide_String
            ) is
        begin
        Close_Paragraph (State);
        State.Content.Blocks.Append ((Kind => Kind, Text => To_Unbounded_Wide_Wide_String (Address)));
        end Add_Media;

    procedure Read_Opening_Tag (
            State  : in out Scan;
            Name   : in     Wide_Wide_String;
            Inside : in     Wide_Text
            ) is
        begin
        if Name = "script" or else Name = "style" then
            Skip_Past_Closing (State, Name);
            --# What is inside these tags is not text for people.
        elsif Name = "svg" then
            Add_Media (State, Drawing, "");
            Skip_Past_Closing (State, Name);
        elsif Name = "a" then
            declare
                Link : constant Wide_Wide_String := Attribute (Inside, "href");
                begin
                if Link /= "" then
                    State.Content.Links.Append (Link);
                    end if;
                end;
        elsif Name = "img" then
            Add_Media (State, Picture, Attribute (Inside, "src"));
        elsif Name = "video" then
            Add_Media (State, Video, Attribute (Inside, "src"));
        elsif Name = "audio" then
            Add_Media (State, Sound, Attribute (Inside, "src"));
            end if;
        end Read_Opening_Tag;

    procedure Read_Comment (
            State : in out Scan
            ) is
        Stop : constant Natural := Found_At (State.Markup, "-->", State.Position);
        begin
        if Stop = 0 then
            State.Position := Length (State.Markup) + 1;
        else
            State.Position := Stop + 3;
            end if;
        end Read_Comment;

    procedure Read_Tag (
            State : in out Scan
            ) is
        Size  : constant Natural := Length (State.Markup);
        Close : Natural;
        begin
        if Matches_At (State.Markup, State.Position, "<!--") then
            Read_Comment (State);
            return;
            end if;
        Close := Mark_At (State.Markup, '>', State.Position, Size);
        if Close = 0 then
            State.Position := Size + 1;
            return;
            --# A tag that never closes: the rest of the page is dropped.
            end if;
        declare
            Inside : constant Wide_Text := Unbounded_Slice (State.Markup, State.Position + 1, Close - 1);
            Name   : constant Wide_Wide_String := Tag_Name (Inside);
            begin
            State.Position := Close + 1;
            if Is_Block_Tag (Name) then
                Close_Paragraph (State);
                end if;
            if not Starts_With_Slash (Inside) then
                Read_Opening_Tag (State, Name, Inside);
                end if;
            end;
        end Read_Tag;
    --# At a "<": a tag, or a comment.

    function Read (
            Markup : in Texts.Wide_Text
            ) return Page_Content is
        State : Scan;
        Char  : Wide_Wide_Character;
        begin
        State.Markup := Markup;
        while State.Position <= Length (State.Markup) loop
            Char := Element (State.Markup, State.Position);
            if Char = '<' then
                Read_Tag (State);
            elsif Char = '&' then
                Read_Entity (State);
            else
                Add_Letter (State, Char);
                State.Position := State.Position + 1;
                end if;
            end loop;
        Close_Paragraph (State);
        return State.Content;
        end Read;

    function Text_Of (
            Content : in Page_Content
            ) return Texts.Wide_Text is
        Text : Wide_Text;
        begin
        for Piece of Content.Blocks loop
            if Piece.Kind = Words then
                Append (Text, Piece.Text);
                Append (Text, Line_Feed);
                end if;
            end loop;
        return Text;
        end Text_Of;

    end Calipso.Pages;
