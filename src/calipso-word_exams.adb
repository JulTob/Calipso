with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Wide_Wide_Hash;

with Calipso.Canvases;
with Calipso.Distributions;
with Calipso.Kinds;

package body Calipso.Word_Exams is

    use type Tokens.Token_Sort;

    package Place_Maps is new Ada.Containers.Indefinite_Hashed_Maps (
            Key_Type        => Wide_Wide_String,
            Element_Type    => Positive,
            Hash            => Ada.Strings.Wide_Wide_Hash,
            Equivalent_Keys => "="
            );

    package Count_Lists is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Natural
            );

    package Kind_Lists is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Symbol
            );

    type Total_Array is array (Symbol) of Natural;

    type Known_Words is record
        Words      : Tokens.Token_List;
        Places     : Place_Maps.Map;
        Seen       : Count_Lists.Vector;
        Kind       : Kind_Lists.Vector;
        Kind_Total : Total_Array := (others => 0);
        --# Kind_Total (K): how many times a word of kind K was seen.
        end record;
    --# Every different word of the studied text, with what the exam needs to know about it.

    procedure Note_Word (
            Known : in out Known_Words;
            Book  : in     Kinds.Book;
            Token : in     Wide_Wide_String
            ) is
        Place : Positive;
        begin
        if not Known.Places.Contains (Token) then
            Known.Words.Append (Token);
            Known.Places.Insert (Token, Natural (Known.Words.Length));
            Known.Seen.Append (0);
            Known.Kind.Append (Kinds.Kind_Of (Book, Token));
            end if;
        Place := Known.Places.Element (Token);
        Known.Seen.Replace_Element (Place, Known.Seen.Element (Place) + 1);
        end Note_Word;

    function Known_From (
            Book    : in Kinds.Book;
            Studied : in Tokens.Token_List
            ) return Known_Words is
        Known : Known_Words;
        Kind  : Symbol;
        begin
        for Token of Studied loop
            if Tokens.Sort_Of (Token) = Tokens.Word then
                Note_Word (Known, Book, Token);
                end if;
            end loop;
        for Place in 1 .. Natural (Known.Words.Length) loop
            Kind := Known.Kind.Element (Place);
            Known.Kind_Total (Kind) := Known.Kind_Total (Kind) + Known.Seen.Element (Place);
            end loop;
        return Known;
        end Known_From;

    function Kinds_Around (
            Book   : in Kinds.Book;
            Unseen : in Tokens.Token_List;
            Place  : in Positive
            ) return Canvases.Canvas is
        Board : Canvases.Canvas;
        begin
        for Near in Place - Side .. Place + Side loop
            if Near = Place then
                Canvases.Append_Blank (Board);
            else
                Canvases.Append_Given (Board, Kinds.Kind_Of (Book, Unseen.Element (Near)));
                end if;
            end loop;
        return Board;
        end Kinds_Around;
    --# A canvas of kinds: Side given kinds, one hole, Side given kinds.

    function Best_Word (
            Known  : in Known_Words;
            Belief : in Distributions.Distribution;
            Length : in Natural
            ) return Wide_Wide_String is
        Best        : Natural := 0;
        Best_Weight : Long_Float := -1.0;
        Kind        : Symbol;
        Share       : Long_Float;
        Weight      : Long_Float;
        begin
        for Place in 1 .. Natural (Known.Words.Length) loop
            if Known.Words.Element (Place)'Length = Length then
                Kind := Known.Kind.Element (Place);
                Share := Long_Float (Known.Seen.Element (Place)) / Long_Float (Known.Kind_Total (Kind));
                Weight := Distributions.Weight_Of (Belief, Kind) * Share;
                if Weight > Best_Weight then
                    Best := Place;
                    Best_Weight := Weight;
                    end if;
                end if;
            end loop;
        if Best = 0 then
            return "";
            end if;
        return Known.Words.Element (Best);
        end Best_Word;
    --# The studied word of this length that the opinion makes most likely. "" if there is none.

    function Exam (
            Plan    : in Pyramids.Pyramid;
            Studied : in Tokens.Token_List;
            Unseen  : in Tokens.Token_List;
            Step    : in Positive := Default_Step
            ) return Result is
        Book   : constant Kinds.Book := Pyramids.Book_Of (Plan);
        Known  : constant Known_Words := Known_From (Book, Studied);
        Last   : constant Integer := Integer (Unseen.Length) - Side;
        Place  : Positive := Side + 1;
        Outcome : Result;
        begin
        while Place <= Last loop
            declare
                Truth : constant Wide_Wide_String := Unseen.Element (Place);
                begin
                if Tokens.Sort_Of (Truth) = Tokens.Word then
                    Outcome.Asked := Outcome.Asked + 1;
                    if Best_Word (
                           Known,
                           Pyramids.Kind_Opinion (Plan, Kinds_Around (Book, Unseen, Place), Side + 1),
                           Truth'Length
                           ) = Truth
                    then
                        Outcome.Right := Outcome.Right + 1;
                        end if;
                    end if;
                end;
            Place := Place + Step;
            end loop;
        return Outcome;
        end Exam;

    end Calipso.Word_Exams;
