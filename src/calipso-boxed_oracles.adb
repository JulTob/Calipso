package body Calipso.Boxed_Oracles is

    function Rule_Of (
            Allowed : in Permission
            ) return Cell_Rule is
        begin
        return (Is_Free => False, Allowed => Allowed);
        end Rule_Of;

    procedure Allow_Evenly (
            Kept    : in out Distributions.Distribution;
            Allowed : in     Permission
            ) is
        begin
        for Value in 1 .. Kept.Size loop
            if Allowed (Value) then
                Distributions.Set_Weight (Kept, Value, 1.0);
                end if;
            end loop;
        end Allow_Evenly;
    --# Every allowed symbol is as good as another.

    function Kept_Part (
            Belief  : in Distributions.Distribution;
            Allowed : in Permission
            ) return Distributions.Distribution is
        Kept : Distributions.Distribution := Distributions.Zero (Belief.Size);
        begin
        for Value in 1 .. Belief.Size loop
            if Allowed (Value) then
                Distributions.Set_Weight (Kept, Value, Distributions.Weight_Of (Belief, Value));
                end if;
            end loop;
        if Distributions.Total (Kept) = 0.0 then
            Allow_Evenly (Kept, Allowed);
            --# The brain gave no chance to anything allowed.
            end if;
        if Distributions.Total (Kept) = 0.0 then
            return Belief;
            --# Nothing at all is allowed here: the rule cannot be obeyed, so it is not applied.
            end if;
        return Distributions.Normalized (Kept);
        end Kept_Part;

    overriding function Alphabet_Size (
            Self : in Boxed_Oracle
            ) return Symbol is
        begin
        return Self.Inner.Alphabet_Size;
        end Alphabet_Size;

    overriding function Reach (
            Self : in Boxed_Oracle
            ) return Natural is
        begin
        return Self.Inner.Reach;
        end Reach;

    overriding function Opinion (
            Self     : in Boxed_Oracle;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution is
        Belief : constant Distributions.Distribution := Self.Inner.Opinion (Board, Position);
        begin
        if Position > Natural (Self.Rules.Length) then
            return Belief;
            end if;
        if Self.Rules.Element (Position).Is_Free then
            return Belief;
            end if;
        return Kept_Part (Belief, Self.Rules.Element (Position).Allowed);
        end Opinion;

    end Calipso.Boxed_Oracles;
