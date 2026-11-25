--  A program that changes a text at fixed points and lets the rest settle.
--
--  Usage:
--     calipso_settle CORPUS TEXT [pin=PLACE:LETTERS] [wrong=PLACE] [sure=X] [signed=X] [model=M] [passes=N]
--
--  It studies CORPUS, writes TEXT on a canvas, and reads it again and again until
--  nothing changes. Places count letters from 1.
--
--     pin=PLACE:LETTERS  these letters are written from PLACE on, and they are certain
--     wrong=PLACE        the letter at PLACE is surely wrong: it must change
--     sure=X             how sure every other letter is, as a chance from 0 to 1
--     signed=X           the same dial on the scale from -1 (surely wrong) through
--                        0 (no idea) to 1 (surely right). 0.99 if neither is said
--     model=M            how the signed dial is read as a chance: straight (two straight
--                        lines, if not said) or curved (the tanh of half the evidence)
--     passes=N           the most readings (8 if not said)
--
--  It mirrors reference/settle.py: with the same arguments it writes the same.

with Ada.Command_Line;
with Ada.Containers.Vectors;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Wide_Wide_Unbounded;

with Calipso.Alphabets;
with Calipso.Anchored_Oracles;
with Calipso.Canvases;
with Calipso.Certainties;
with Calipso.Console;
with Calipso.Counting_Oracles;
with Calipso.Settling;
with Calipso.Texts;

procedure Calipso_Settle is

    use Calipso;

    package Wide_Texts renames Ada.Strings.Wide_Wide_Unbounded;

    Default_Signed : constant Certainties.Signed_Certainty := 0.99;
    Most_Digits    : constant Positive := 9;

    type Pin is record
        Place   : Positive := 1;
        Letters : Texts.Wide_Text;
        end record;
    --# Letters to write from Place on, and to hold as certain.

    package Pin_Vectors is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Pin
            );

    package Place_Vectors is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Positive
            );

    type Choices is record
        Pins     : Pin_Vectors.Vector;
        Wrongs   : Place_Vectors.Vector;
        Has_Sure : Boolean := False;
        --# True when the dial was given as a chance (sure=), False when on the signed scale.
        Sure     : Certainties.Certainty := 1.0;
        Signed   : Certainties.Signed_Certainty := Default_Signed;
        Model    : Certainties.Dial_Model := Certainties.Straight;
        Passes   : Positive := Settling.Default_Passes;
        end record;
    --# What the command line asked for.

    Bad_Argument : exception;

    function Whole_Number (
            Word  : in String;
            Least : in Natural
            ) return Natural is
        Value : Natural := 0;
        begin
        if Word'Length = 0 or else Word'Length > Most_Digits then
            raise Bad_Argument with "a whole number was expected. Found: " & Word;
            end if;
        for Char of Word loop
            if Char not in '0' .. '9' then
                raise Bad_Argument with "a whole number was expected. Found: " & Word;
                end if;
            Value := Value * 10 + (Character'Pos (Char) - Character'Pos ('0'));
            end loop;
        if Value < Least then
            raise Bad_Argument with "the number must be " & Console.Image (Least) & " or more. Found: " & Word;
            end if;
        return Value;
        end Whole_Number;

    function Read_Real (
            Word : in String
            ) return Long_Float is
        begin
        return Long_Float'Value (Word);
        exception
        when Constraint_Error =>
            raise Bad_Argument with "a number was expected, like 0.9. Found: " & Word;
        end Read_Real;

    function Real_Number (
            Word    : in String;
            Lowest  : in Long_Float;
            Highest : in Long_Float
            ) return Long_Float is
        Value : constant Long_Float := Read_Real (Word);
        begin
        if Value < Lowest or else Value > Highest then
            raise Bad_Argument with "the number is outside its scale. Found: " & Word;
            end if;
        return Value;
        end Real_Number;

    function Pin_Of (
            Value : in String
            ) return Pin is
        Colon : constant Natural := Ada.Strings.Fixed.Index (Value, ":");
        begin
        if Colon = 0 or else Colon = Value'Last then
            raise Bad_Argument with "a pin is written PLACE:LETTERS, for example pin=5:ga. Found: " & Value;
            end if;
        return (
            Place   => Whole_Number (Value (Value'First .. Colon - 1), 1),
            Letters => Wide_Texts.To_Unbounded_Wide_Wide_String (Console.From_UTF_8 (Value (Colon + 1 .. Value'Last)))
            );
        end Pin_Of;

    function Model_Named (
            Name : in String
            ) return Certainties.Dial_Model is
        begin
        if Name = "straight" then
            return Certainties.Straight;
            end if;
        if Name = "curved" then
            return Certainties.Curved;
            end if;
        raise Bad_Argument with "the model is straight or curved. Found: " & Name;
        end Model_Named;

    procedure Take_Option (
            Wanted : in out Choices;
            Word   : in     String
            ) is
        Equal : constant Natural := Ada.Strings.Fixed.Index (Word, "=");
        begin
        if Equal = 0 then
            raise Bad_Argument with "options are written name=value, for example signed=0.9. Found: " & Word;
            end if;
        declare
            Name  : constant String := Word (Word'First .. Equal - 1);
            Value : constant String := Word (Equal + 1 .. Word'Last);
            begin
            if Name = "pin" then
                Wanted.Pins.Append (Pin_Of (Value));
            elsif Name = "wrong" then
                Wanted.Wrongs.Append (Whole_Number (Value, 1));
            elsif Name = "sure" then
                Wanted.Sure := Certainties.Certainty (Real_Number (Value, 0.0, 1.0));
                Wanted.Has_Sure := True;
            elsif Name = "signed" then
                Wanted.Signed := Certainties.Signed_Certainty (Real_Number (Value, -1.0, 1.0));
                Wanted.Has_Sure := False;
            elsif Name = "model" then
                Wanted.Model := Model_Named (Value);
            elsif Name = "passes" then
                Wanted.Passes := Whole_Number (Value, 1);
            else
                raise Bad_Argument with "there is no option called " & Name;
                end if;
            end;
        end Take_Option;
    --# One option, written name=value.

    procedure Check_Place (
            Place  : in Positive;
            Last   : in Natural;
            Length : in Natural
            ) is
        begin
        if Last > Length then
            raise Bad_Argument with
                "place " & Console.Image (Place) & " is beyond the end of the text, which has "
                & Console.Image (Length) & " letters";
            end if;
        end Check_Place;

    procedure Write_Pins (
            Symbols : in out Texts.Symbol_Text;
            Wanted  : in     Choices;
            Letters : in     Alphabets.Alphabet
            ) is
        begin
        for Pinned of Wanted.Pins loop
            declare
                Plain  : constant Wide_Wide_String := Wide_Texts.To_Wide_Wide_String (Pinned.Letters);
                Values : constant Texts.Symbol_Text := Texts.Encoded (Plain, Letters);
                begin
                Check_Place (Pinned.Place, Pinned.Place + Plain'Length - 1, Natural (Symbols.Length));
                for Index in 1 .. Natural (Values.Length) loop
                    Symbols.Replace_Element (Pinned.Place + Index - 1, Values.Element (Index));
                    end loop;
                end;
            end loop;
        end Write_Pins;
    --# The pinned letters replace what the text had.

    function Rest_Certainty (
            Wanted : in Choices;
            Size   : in Symbol
            ) return Certainties.Certainty is
        begin
        if Wanted.Has_Sure then
            return Wanted.Sure;
            end if;
        return Certainties.Certainty_Of (Wanted.Signed, Size, Wanted.Model);
        end Rest_Certainty;
    --# The dial of every letter that is neither pinned nor marked, whichever scale it was given on.

    function Anchors_For (
            Symbols : in Texts.Symbol_Text;
            Wanted  : in Choices;
            Size    : in Symbol
            ) return Anchored_Oracles.Anchor_List is
        Anchors : Anchored_Oracles.Anchor_List := Settling.Even_Anchors (Symbols, Rest_Certainty (Wanted, Size));
        Place   : Positive;
        begin
        for Pinned of Wanted.Pins loop
            for Index in 1 .. Wide_Texts.Length (Pinned.Letters) loop
                Place := Pinned.Place + Index - 1;
                Anchors.Replace_Element (Place, Anchored_Oracles.Anchor_Of (Symbols.Element (Place), 1.0));
                end loop;
            end loop;
        for Marked of Wanted.Wrongs loop
            Check_Place (Marked, Marked, Natural (Symbols.Length));
            Anchors.Replace_Element (Marked, Anchored_Oracles.Anchor_Of (Symbols.Element (Marked), 0.0));
            end loop;
        return Anchors;
        end Anchors_For;
    --# Every letter holds on as the dial says; pinned letters are certain; marked letters are surely wrong.

    function Text_On (
            Board   : in Canvases.Canvas;
            Letters : in Alphabets.Alphabet
            ) return Wide_Wide_String is
        Symbols : Texts.Symbol_Text;
        begin
        for Position in 1 .. Canvases.Length (Board) loop
            Symbols.Append (Canvases.Symbol_At (Board, Position));
            end loop;
        return Texts.Decoded (Symbols, Letters);
        end Text_On;

    function Yes_Or_No (
            Answer : in Boolean
            ) return String is
        begin
        if Answer then
            return "yes";
            end if;
        return "no";
        end Yes_Or_No;

    procedure Run (
            Corpus_Name : in String;
            Text        : in Wide_Wide_String;
            Wanted      : in Choices
            ) is
        Letters : Alphabets.Alphabet;
        Speller : Counting_Oracles.Counting_Oracle;
        Symbols : Texts.Symbol_Text;
        Anchors : Anchored_Oracles.Anchor_List;
        Board   : Canvases.Canvas;
        Outcome : Settling.Report;
        begin
        Texts.Learn_Alphabet (Corpus_Name, Letters);
        Counting_Oracles.Train (Speller, Texts.Read_Symbols (Corpus_Name, Letters), Alphabets.Size (Letters));
        Symbols := Texts.Encoded (Text, Letters);
        Write_Pins (Symbols, Wanted, Letters);
        Anchors := Anchors_For (Symbols, Wanted, Alphabets.Size (Letters));
        Board := Settling.Written (Symbols);
        Console.Put_Wide_Line ("Before: " & Text_On (Board, Letters));
        Settling.Settle (Board, Speller, Anchors, Outcome, Wanted.Passes);
        Console.Put_Wide_Line ("After:  " & Text_On (Board, Letters));
        Console.Put_Line (
            "Readings: " & Console.Image (Outcome.Passes) & ". Letters rewritten: " & Console.Image (Outcome.Changes)
            & ". Settled: " & Yes_Or_No (Outcome.Is_Settled) & "."
            );
        end Run;

    procedure Show_Usage is
        begin
        Console.Put_Line ("Usage:");
        Console.Put_Line (
            "   calipso_settle CORPUS TEXT [pin=PLACE:LETTERS] [wrong=PLACE] [sure=X] [signed=X] [model=M] [passes=N]"
            );
        end Show_Usage;

    procedure Settle_Command is
        Wanted : Choices;
        begin
        for Index in 3 .. Ada.Command_Line.Argument_Count loop
            Take_Option (Wanted, Ada.Command_Line.Argument (Index));
            end loop;
        Run (Ada.Command_Line.Argument (1), Console.From_UTF_8 (Ada.Command_Line.Argument (2)), Wanted);
        end Settle_Command;

    begin
    if Ada.Command_Line.Argument_Count >= 2 then
        Settle_Command;
    else
        Show_Usage;
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
        end if;
    exception
    when Problem : Texts.Reading_Error | Bad_Argument =>
        Console.Put_Line ("Error: " & Ada.Exceptions.Exception_Message (Problem));
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
    end Calipso_Settle;
