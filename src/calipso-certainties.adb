package body Calipso.Certainties is

    function Clamped (
            Value   : in Long_Float;
            Lowest  : in Long_Float;
            Highest : in Long_Float
            ) return Long_Float is
        begin
        return Long_Float'Max (Lowest, Long_Float'Min (Highest, Value));
        end Clamped;
    --# Arithmetic with fractions can land a hair outside the scale. This brings it back.

    function Chance_Level (
            Size : in Symbol
            ) return Certainty is
        begin
        return Certainty (1.0 / Long_Float (Size));
        end Chance_Level;

    function Certainty_Of (
            Signed : in Signed_Certainty;
            Size   : in Symbol
            ) return Certainty is
        Chance : constant Long_Float := Long_Float (Chance_Level (Size));
        Lean   : constant Long_Float := Long_Float (Signed);
        begin
        if Lean >= 0.0 then
            return Certainty (Clamped (Chance + Lean * (1.0 - Chance), 0.0, 1.0));
            end if;
        return Certainty (Clamped ((1.0 + Lean) * Chance, 0.0, 1.0));
        end Certainty_Of;

    function Signed_Of (
            Plain : in Certainty;
            Size  : in Symbol
            ) return Signed_Certainty is
        Chance : constant Long_Float := Long_Float (Chance_Level (Size));
        Sure   : constant Long_Float := Long_Float (Plain);
        begin
        if Sure >= Chance then
            return Signed_Certainty (Clamped ((Sure - Chance) / (1.0 - Chance), -1.0, 1.0));
            end if;
        return Signed_Certainty (Clamped (Sure / Chance - 1.0, -1.0, 1.0));
        end Signed_Of;

    end Calipso.Certainties;
