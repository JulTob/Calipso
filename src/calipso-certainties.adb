with Ada.Numerics.Long_Elementary_Functions;

package body Calipso.Certainties is

    use Ada.Numerics.Long_Elementary_Functions;

    Smallest_Chance : constant Long_Float := 1.0E-15;

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

    function Sigmoid (
            Value : in Long_Float
            ) return Long_Float is
        begin
        return 1.0 / (1.0 + Exp (-Value));
        end Sigmoid;

    function Logit (
            Chance : in Long_Float
            ) return Long_Float is
        begin
        return Log (Chance / (1.0 - Chance));
        end Logit;
    --# The sigmoid, backwards: the evidence that gives this chance.

    function Signed_From (
            Weight : in Evidence
            ) return Signed_Certainty is
        Most   : constant Long_Float := Long_Float (Most_Evidence);
        Shrink : constant Long_Float := Exp (-Clamped (Long_Float (Weight), -Most, Most));
        begin
        return Signed_Certainty (Clamped ((1.0 - Shrink) / (1.0 + Shrink), -1.0, 1.0));
        end Signed_From;
    --# tanh (Weight / 2), written with one exponential.

    function To_Evidence (
            Signed : in Signed_Certainty
            ) return Evidence is
        Limit : constant Long_Float := Long_Float (Signed_From (Most_Evidence));
        Held  : constant Long_Float := Clamped (Long_Float (Signed), -Limit, Limit);
        begin
        return Evidence (Log ((1.0 + Held) / (1.0 - Held)));
        end To_Evidence;

    function To_Evidence (
            Plain : in Certainty;
            Size  : in Symbol
            ) return Evidence is
        Most : constant Long_Float := Long_Float (Most_Evidence);
        Held : constant Long_Float := Clamped (Long_Float (Plain), Smallest_Chance, 1.0 - Smallest_Chance);
        begin
        return Evidence (Clamped (Logit (Held) - Logit (Long_Float (Chance_Level (Size))), -Most, Most));
        end To_Evidence;

    function Certainty_From (
            Weight : in Evidence;
            Size   : in Symbol
            ) return Certainty is
        Most : constant Long_Float := Long_Float (Most_Evidence);
        Held : constant Long_Float := Clamped (Long_Float (Weight), -Most, Most);
        begin
        return Certainty (Clamped (Sigmoid (Held + Logit (Long_Float (Chance_Level (Size)))), 0.0, 1.0));
        end Certainty_From;

    function Certainty_Of (
            Signed : in Signed_Certainty;
            Size   : in Symbol;
            Model  : in Dial_Model
            ) return Certainty is
        begin
        if Model = Straight then
            return Certainty_Of (Signed, Size);
            end if;
        if Signed >= Surely_Right then
            return 1.0;
            end if;
        if Signed <= Surely_Wrong then
            return 0.0;
            end if;
        return Certainty_From (To_Evidence (Signed), Size);
        end Certainty_Of;

    function "&" (
            Left  : in Signed_Certainty;
            Right : in Signed_Certainty
            ) return Signed_Certainty is
        Bottom : constant Long_Float := 1.0 + Long_Float (Left) * Long_Float (Right);
        begin
        if Bottom = 0.0 then
            return No_Idea;
            --# "Surely right" and "surely wrong" together: they cancel.
            end if;
        return Signed_Certainty (Clamped ((Long_Float (Left) + Long_Float (Right)) / Bottom, -1.0, 1.0));
        end "&";

    end Calipso.Certainties;
