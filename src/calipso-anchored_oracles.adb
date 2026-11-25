package body Calipso.Anchored_Oracles is

    function Anchor_Of (
            Held : in Symbol;
            Sure : in Certainties.Certainty
            ) return Anchor is
        begin
        return (Is_Free => False, Held => Held, Sure => Sure);
        end Anchor_Of;

    function Anchor_Of (
            Held   : in Symbol;
            Signed : in Certainties.Signed_Certainty;
            Size   : in Symbol
            ) return Anchor is
        begin
        return Anchor_Of (Held, Certainties.Certainty_Of (Signed, Size));
        end Anchor_Of;

    function Memory_Alone (
            Toward : in Anchor;
            Size   : in Symbol
            ) return Distributions.Distribution
        with Pre => Size >= 2;

    function Memory_Alone (
            Toward : in Anchor;
            Size   : in Symbol
            ) return Distributions.Distribution is
        Sure   : constant Long_Float := Long_Float (Toward.Sure);
        Others : constant Long_Float := (1.0 - Sure) / Long_Float (Size - 1);
        Memory : Distributions.Distribution := Distributions.Zero (Size);
        begin
        for Value in 1 .. Size loop
            if Value = Toward.Held then
                Distributions.Set_Weight (Memory, Value, Sure);
            else
                Distributions.Set_Weight (Memory, Value, Others);
                end if;
            end loop;
        return Memory;
        end Memory_Alone;
    --# What the memory of the cell says, with no brain: Sure for the held symbol, the rest shared out.

    function Joined (
            Belief : in Distributions.Distribution;
            Memory : in Distributions.Distribution
            ) return Distributions.Distribution is
        Result : Distributions.Distribution := Distributions.Zero (Belief.Size);
        begin
        for Value in 1 .. Belief.Size loop
            Distributions.Set_Weight (
                Result,
                Value,
                Distributions.Weight_Of (Memory, Value) * Distributions.Weight_Of (Belief, Value)
                );
            end loop;
        return Result;
        end Joined;
    --# Symbol by symbol, the weight of one times the weight of the other. Not yet scaled to add up to 1.

    function Pulled (
            Belief : in Distributions.Distribution;
            Toward : in Anchor
            ) return Distributions.Distribution is
        begin
        if Toward.Is_Free or else Belief.Size < 2 then
            return Belief;
            end if;
        declare
            Memory : constant Distributions.Distribution := Memory_Alone (Toward, Belief.Size);
            Both   : constant Distributions.Distribution := Joined (Belief, Memory);
            begin
            if Distributions.Total (Both) = 0.0 then
                return Distributions.Normalized (Memory);
                --# The brain gives no chance to anything the memory allows: the memory decides alone.
                end if;
            return Distributions.Normalized (Both);
            end;
        end Pulled;

    overriding function Alphabet_Size (
            Self : in Anchored_Oracle
            ) return Symbol is
        begin
        return Self.Inner.Alphabet_Size;
        end Alphabet_Size;

    overriding function Reach (
            Self : in Anchored_Oracle
            ) return Natural is
        begin
        return Self.Inner.Reach;
        end Reach;

    overriding function Opinion (
            Self     : in Anchored_Oracle;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution is
        Belief : constant Distributions.Distribution := Self.Inner.Opinion (Board, Position);
        begin
        if Position > Natural (Self.Anchors.Length) then
            return Belief;
            end if;
        return Pulled (Belief, Self.Anchors.Element (Position));
        end Opinion;

    end Calipso.Anchored_Oracles;
