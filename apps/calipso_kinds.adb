--  A program to try the ways of deciding kinds.
--
--  Usage:
--     calipso_kinds alike CORPUS WORD OTHER... [reach=N] [context=kinds|words] [case=fold|keep]
--     calipso_kinds exam CORPUS [kinds=shape|company] [reach=N] [context=kinds|words]
--                        [case=fold|keep] [axes=N] [rounds=N] [groups=N] [step=N]
--
--  alike : describes every word of CORPUS by the company it keeps and says how alike
--          WORD is to each OTHER (cosine: 1 the same company, 0 nothing in common;
--          turn: near 0 they replace each other, near 90 one stands beside the other).
--  exam  : studies the first nine tenths of CORPUS, hides one word in every STEP of
--          the last tenth, and counts how often the level of kinds gets it back.
--
--     kinds=shape|company   how kinds are decided (shape if not said)
--     reach=N               tokens looked at on each side of a word (1)
--     context=kinds|words   what a neighbour counts as (kinds)
--     case=fold|keep        whether "Zebras" and "zebras" are one word (fold)
--     axes=N                numbers kept for each word; 0 keeps them all (24)
--     rounds=N              how long each axis is searched for (30)
--     groups=N              how many groups of words are made (80)
--     step=N                one word in every N is hidden (9)
--
--  It mirrors reference/kinds.py: with the same arguments it writes the same.

with Ada.Command_Line;
with Ada.Containers.Indefinite_Vectors;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Wide_Wide_Unbounded;

with Calipso.Company;
with Calipso.Console;
with Calipso.Kind_Makers;
with Calipso.Kinds;
with Calipso.Pyramids;
with Calipso.Texts;
with Calipso.Tokens;
with Calipso.Vectors;
with Calipso.Word_Exams;

procedure Calipso_Kinds is

    use Calipso;
    use type Company.Context_Sort;
    use type Kind_Makers.Maker;

    package Wide_Texts renames Ada.Strings.Wide_Wide_Unbounded;

    package Word_Lists is new Ada.Containers.Indefinite_Vectors (
            Index_Type   => Positive,
            Element_Type => String
            );

    Most_Digits : constant Positive := 9;

    type Choices is record
        Making : Kind_Makers.Settings;
        Step   : Positive := Word_Exams.Default_Step;
        Plain  : Word_Lists.Vector;
        --# The arguments that are not options, in order.
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

    procedure Take_Option (
            Wanted : in out Choices;
            Name   : in     String;
            Value  : in     String
            ) is
        begin
        if Name = "kinds" and then Value = "shape" then
            Wanted.Making.Way := Kind_Makers.By_Shape;
        elsif Name = "kinds" and then Value = "company" then
            Wanted.Making.Way := Kind_Makers.By_Company;
        elsif Name = "context" and then Value = "kinds" then
            Wanted.Making.Neighbours.Context := Company.As_Kinds;
        elsif Name = "context" and then Value = "words" then
            Wanted.Making.Neighbours.Context := Company.As_Words;
        elsif Name = "case" and then Value = "fold" then
            Wanted.Making.Neighbours.Fold_Case := True;
        elsif Name = "case" and then Value = "keep" then
            Wanted.Making.Neighbours.Fold_Case := False;
        elsif Name = "reach" then
            Wanted.Making.Neighbours.Reach := Whole_Number (Value, 1);
        elsif Name = "axes" then
            Wanted.Making.Axis_Count := Whole_Number (Value, 0);
        elsif Name = "rounds" then
            Wanted.Making.Rounds := Whole_Number (Value, 1);
        elsif Name = "groups" then
            Wanted.Making.Group_Count := Whole_Number (Value, 1);
        elsif Name = "step" then
            Wanted.Step := Whole_Number (Value, 1);
        else
            raise Bad_Argument with "this option is not understood: " & Name & "=" & Value;
            end if;
        end Take_Option;

    procedure Take_Argument (
            Wanted : in out Choices;
            Word   : in     String
            ) is
        Equal : constant Natural := Ada.Strings.Fixed.Index (Word, "=");
        begin
        if Equal = 0 then
            Wanted.Plain.Append (Word);
        else
            Take_Option (Wanted, Word (Word'First .. Equal - 1), Word (Equal + 1 .. Word'Last));
            end if;
        end Take_Argument;
    --# name=value is an option; anything else is kept in order.

    function Company_Words (
            Options : in Company.Settings
            ) return String is
        Context  : constant String := (if Options.Context = Company.As_Kinds then "kinds" else "words");
        Capitals : constant String := (if Options.Fold_Case then "folded" else "kept");
        begin
        return "reach " & Console.Image (Options.Reach) & ", neighbours as " & Context & ", capitals " & Capitals;
        end Company_Words;

    procedure Show_Pair (
            Table : in Company.Table;
            Word  : in String;
            Other : in String
            ) is
        Wide_Other : constant Wide_Wide_String := Console.From_UTF_8 (Other);
        begin
        if not Company.Has_Word (Table, Wide_Other) then
            Console.Put_Line (Other & " is not in the text.");
            return;
            end if;
        declare
            Mine   : constant Vectors.Vector := Company.Vector_Of (Table, Console.From_UTF_8 (Word));
            Theirs : constant Vectors.Vector := Company.Vector_Of (Table, Wide_Other);
            Cosine : constant Long_Float := Vectors.Cosine (Mine, Theirs) + 0.0;
            Turn   : constant Long_Float := Vectors.Turn (Mine, Theirs) + 0.0;
            --# Adding 0 turns a "minus zero" into a plain zero, so it is written without a sign.
            begin
            Console.Put_Line (
                Word & " / " & Other & ": cosine " & Console.Image (Cosine, 3) & ", turn " & Console.Image (Turn, 1)
                & " degrees"
                );
            end;
        end Show_Pair;

    procedure Alike (
            Corpus_Name : in String;
            Wanted      : in Choices
            ) is
        Whole   : constant Wide_Wide_String := Wide_Texts.To_Wide_Wide_String (Texts.Whole_Text (Corpus_Name));
        Sample  : constant Tokens.Token_List := Tokens.Split (Whole);
        Options : Company.Settings := Wanted.Making.Neighbours;
        Width   : Natural := 0;
        begin
        if Natural (Wanted.Plain.Length) < 2 then
            raise Bad_Argument with "alike needs a word and at least one other word";
            end if;
        Options.Every_Word := True;
        declare
            Table : constant Company.Table := Company.Built (Sample, Kinds.Built (Sample), Options);
            Word  : constant String := Wanted.Plain.First_Element;
            begin
            if Company.Row_Count (Table) > 0 then
                Width := Company.Vector_At (Table, 1)'Length;
                end if;
            Console.Put_Line (
                "Company: " & Company_Words (Options) & ". " & Console.Image (Company.Row_Count (Table))
                & " words, each described by " & Console.Image (Width) & " counts."
                );
            if not Company.Has_Word (Table, Console.From_UTF_8 (Word)) then
                Console.Put_Line (Word & " is not in the text.");
                return;
                end if;
            for Number in 2 .. Natural (Wanted.Plain.Length) loop
                Show_Pair (Table, Word, Wanted.Plain.Element (Number));
                end loop;
            end;
        end Alike;

    function Making_Words (
            Making : in Kind_Makers.Settings
            ) return String is
        begin
        if Making.Way = Kind_Makers.By_Shape then
            return "by shape";
            end if;
        return "by company (" & Company_Words (Making.Neighbours) & ", " & Console.Image (Making.Axis_Count)
               & " axes, " & Console.Image (Making.Group_Count) & " groups)";
        end Making_Words;

    function Share_Of (
            Outcome : in Word_Exams.Result
            ) return Long_Float is
        begin
        if Outcome.Asked = 0 then
            return 0.0;
            end if;
        return 100.0 * Long_Float (Outcome.Right) / Long_Float (Outcome.Asked);
        end Share_Of;

    procedure Exam (
            Corpus_Name : in String;
            Wanted      : in Choices
            ) is
        Whole   : constant Wide_Wide_String := Wide_Texts.To_Wide_Wide_String (Texts.Whole_Text (Corpus_Name));
        Cut     : constant Natural := (Whole'Length * 9) / 10;
        Studied : constant Wide_Wide_String := Whole (Whole'First .. Whole'First + Cut - 1);
        Unseen  : constant Wide_Wide_String := Whole (Whole'First + Cut .. Whole'Last);
        Plan    : Pyramids.Pyramid;
        Outcome : Word_Exams.Result;
        begin
        Pyramids.Study (Plan, Studied, Wanted.Making);
        Outcome := Word_Exams.Exam (Plan, Tokens.Split (Studied), Tokens.Split (Unseen), Wanted.Step);
        Console.Put_Line (
            "Kinds: " & Making_Words (Wanted.Making) & ". "
            & Console.Image (Natural (Kinds.Kind_Count (Pyramids.Book_Of (Plan)))) & " kinds."
            );
        Console.Put_Line (
            "Hidden words: " & Console.Image (Outcome.Asked) & ". Rebuilt exactly: " & Console.Image (Outcome.Right)
            & " (" & Console.Image (Share_Of (Outcome), 1) & " %)."
            );
        end Exam;

    procedure Show_Usage is
        begin
        Console.Put_Line ("Usage:");
        Console.Put_Line (
            "   calipso_kinds alike CORPUS WORD OTHER... [reach=N] [context=kinds|words] [case=fold|keep]"
            );
        Console.Put_Line (
            "   calipso_kinds exam CORPUS [kinds=shape|company] [reach=N] [context=kinds|words] [case=fold|keep]"
            );
        Console.Put_Line ("                      [axes=N] [rounds=N] [groups=N] [step=N]");
        end Show_Usage;

    function Is_Command (
            Word : in String
            ) return Boolean is
        begin
        return Word = "alike" or else Word = "exam";
        end Is_Command;

    procedure Run_Command is
        Wanted : Choices;
        begin
        for Index in 3 .. Ada.Command_Line.Argument_Count loop
            Take_Argument (Wanted, Ada.Command_Line.Argument (Index));
            end loop;
        if Ada.Command_Line.Argument (1) = "alike" then
            Alike (Ada.Command_Line.Argument (2), Wanted);
        else
            Exam (Ada.Command_Line.Argument (2), Wanted);
            end if;
        end Run_Command;

    begin
    if Ada.Command_Line.Argument_Count >= 2 and then Is_Command (Ada.Command_Line.Argument (1)) then
        Run_Command;
    else
        Show_Usage;
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
        end if;
    exception
    when Problem : Texts.Reading_Error | Bad_Argument =>
        Console.Put_Line ("Error: " & Ada.Exceptions.Exception_Message (Problem));
        Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
    end Calipso_Kinds;
