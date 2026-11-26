--  A program that writes, by either method.
--
--  Usage:
--     calipso_write CORPUS [method=flat|spell|pick] [words=N] [texts=N] [seed=N]
--
--  It studies CORPUS and then writes.
--
--     method=flat   one level: letters only (the method Calipso started with)
--     method=spell  two levels: kinds of word, then the letter brain spells each word in its box
--     method=pick   two levels: kinds of word, then a word seen in that kind is taken
--     words=N       about how many words each text has (12 if not said)
--     texts=N       how many texts to write (3 if not said)
--     seed=N        where the dice start (1 if not said)
--
--  A line feed inside a text is shown as " / ", so that every text stays on one line.
--
--  It mirrors reference/write.py: with the same arguments it writes the same.

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Wide_Wide_Unbounded;

with Calipso.Alphabets;
with Calipso.Console;
with Calipso.Counting_Oracles;
with Calipso.Pyramids;
with Calipso.Random_Sources;
with Calipso.Texts;
with Calipso.Tokens;
with Calipso.Writers;

procedure Calipso_Write is

    use Calipso;

    package Wide_Texts renames Ada.Strings.Wide_Wide_Unbounded;

    Default_Words : constant Positive := 12;
    Default_Count : constant Positive := 3;
    Default_Seed  : constant Natural := 1;
    Most_Digits   : constant Positive := 9;
    Shown_Break   : constant Wide_Wide_String := " / ";

    type Method is (Flat, Spell, Pick);

    type Choices is record
        Way   : Method := Spell;
        Words : Positive := Default_Words;
        Count : Positive := Default_Count;
        --# How many texts to write.
        Seed  : Natural := Default_Seed;
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

    function Method_Named (
            Name : in String
            ) return Method is
        begin
        if Name = "flat" then
            return Flat;
            end if;
        if Name = "spell" then
            return Spell;
            end if;
        if Name = "pick" then
            return Pick;
            end if;
        raise Bad_Argument with "the method is flat, spell or pick. Found: " & Name;
        end Method_Named;

    function Name_Of (
            Way : in Method
            ) return String is
        begin
        case Way is
            when Flat  => return "flat";
            when Spell => return "spell";
            when Pick  => return "pick";
            end case;
        end Name_Of;

    procedure Take_Option (
            Wanted : in out Choices;
            Word   : in     String
            ) is
        Equal : constant Natural := Ada.Strings.Fixed.Index (Word, "=");
        begin
        if Equal = 0 then
            raise Bad_Argument with "options are written name=value, for example words=20. Found: " & Word;
            end if;
        declare
            Name  : constant String := Word (Word'First .. Equal - 1);
            Value : constant String := Word (Equal + 1 .. Word'Last);
            begin
            if Name = "method" then
                Wanted.Way := Method_Named (Value);
            elsif Name = "words" then
                Wanted.Words := Whole_Number (Value, 1);
            elsif Name = "texts" then
                Wanted.Count := Whole_Number (Value, 1);
            elsif Name = "seed" then
                Wanted.Seed := Whole_Number (Value, 0);
            else
                raise Bad_Argument with "there is no option called " & Name;
                end if;
            end;
        end Take_Option;
    --# One option, written name=value.

    function Shown (
            Text : in Wide_Wide_String
            ) return Wide_Wide_String is
        Result : Wide_Texts.Unbounded_Wide_Wide_String;
        begin
        for Char of Text loop
            if Char = Tokens.Line_Feed then
                Wide_Texts.Append (Result, Shown_Break);
            else
                Wide_Texts.Append (Result, Char);
                end if;
            end loop;
        return Wide_Texts.To_Wide_Wide_String (Result);
        end Shown;
    --# The text on one line: every line feed is drawn as " / ".

    procedure Write_Texts (
            Author : in Writers.Writer'Class;
            Wanted : in Choices
            ) is
        Dice   : Random_Sources.Generator;
        Result : Texts.Wide_Text;
        begin
        for Number in 1 .. Wanted.Count loop
            Dice := Random_Sources.Seeded (Wanted.Seed + Number - 1);
            Author.Write (Dice, Wanted.Words, Result);
            Console.Put_Wide_Line (
                Console.From_UTF_8 (Console.Image (Number) & ": ") & Shown (Wide_Texts.To_Wide_Wide_String (Result))
                );
            end loop;
        end Write_Texts;
    --# The same steps whoever the author is: this is what the Writer contract buys.

    function Passing_Of (
            Way : in Method
            ) return Pyramids.Handover is
        begin
        if Way = Pick then
            return Pyramids.Pick;
            end if;
        return Pyramids.Spell;
        end Passing_Of;

    procedure Run (
            Corpus_Name : in String;
            Wanted      : in Choices
            ) is
        Letters : Alphabets.Alphabet;
        Speller : aliased Counting_Oracles.Counting_Oracle;
        Plan    : aliased Pyramids.Pyramid;
        begin
        Texts.Learn_Alphabet (Corpus_Name, Letters);
        Counting_Oracles.Train (Speller, Texts.Read_Symbols (Corpus_Name, Letters), Alphabets.Size (Letters));
        Console.Put_Line (
            "Method: " & Name_Of (Wanted.Way) & ". About " & Console.Image (Wanted.Words) & " words in each text."
            );
        if Wanted.Way = Flat then
            declare
                Author : Writers.Flat_Writer (Speller'Access);
                begin
                Author.Letters := Letters;
                Write_Texts (Author, Wanted);
                end;
            return;
            end if;
        Pyramids.Study (Plan, Wide_Texts.To_Wide_Wide_String (Texts.Whole_Text (Corpus_Name)));
        declare
            Author : Writers.Pyramid_Writer (Plan'Access, Speller'Access);
            begin
            Author.Letters := Letters;
            Author.Passing := Passing_Of (Wanted.Way);
            Write_Texts (Author, Wanted);
            end;
        end Run;

    procedure Show_Usage is
        begin
        Console.Put_Line ("Usage:");
        Console.Put_Line ("   calipso_write CORPUS [method=flat|spell|pick] [words=N] [texts=N] [seed=N]");
        end Show_Usage;

    procedure Write_Command is
        Wanted : Choices;
        begin
        for Index in 2 .. Ada.Command_Line.Argument_Count loop
            Take_Option (Wanted, Ada.Command_Line.Argument (Index));
            end loop;
        Run (Ada.Command_Line.Argument (1), Wanted);
        end Write_Command;

    begin
    if Ada.Command_Line.Argument_Count >= 1 then
        Write_Command;
    else
        Show_Usage;
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
        end if;
    exception
    when Problem : Texts.Reading_Error | Bad_Argument =>
        Console.Put_Line ("Error: " & Ada.Exceptions.Exception_Message (Problem));
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
    end Calipso_Write;
