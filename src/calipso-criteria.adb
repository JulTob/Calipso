with Ada.Numerics.Long_Elementary_Functions;

with Calipso.Brains;
with Calipso.Distributions;

package body Calipso.Criteria is

    package Math renames Ada.Numerics.Long_Elementary_Functions;

    function Same (
            Left  : in Criterion'Class;
            Right : in Criterion'Class
            ) return Boolean is
        begin
        return Left = Right;
        end Same;

    function Certainty_Of (
            Board    : in Canvases.Canvas;
            Model    : in Oracles.Oracle'Class;
            Position : in Positive
            ) return Long_Float is
        Size : constant Symbol := Model.Alphabet_Size;
        begin
        if Size = 1 then
            return 1.0;
            end if;
        declare
            Belief     : constant Distributions.Distribution := Model.Opinion (Board, Position);
            Most_Doubt : constant Long_Float := Math.Log (Long_Float (Size));
            begin
            return 1.0 - Distributions.Entropy (Belief) / Most_Doubt;
            end;
        end Certainty_Of;

    overriding function Readiness (
            Self     : in Certainty;
            Board    : in Canvases.Canvas;
            Model    : in Oracles.Oracle'Class;
            Position : in Positive
            ) return Long_Float is
        pragma Unreferenced (Self);
        begin
        return Certainty_Of (Board, Model, Position);
        end Readiness;

    function Looking_Count (
            Model : in Brains.Brain'Class
            ) return Natural is
        Count : Natural := 0;
        begin
        for Index in 1 .. Brains.Neuron_Count (Model) loop
            if Brains.Neuron_Reach (Model, Index) > 0 then
                Count := Count + 1;
                end if;
            end loop;
        return Count;
        end Looking_Count;
    --# Neurons that look at nothing (reach 0) always say the same; they are left out.

    function Shared_Bets (
            Model    : in Brains.Brain'Class;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Long_Float is
        Size   : constant Symbol := Brains.Alphabet_Size (Model);
        Lowest : Distributions.Score_Array (1 .. Size) := (others => 1.0);
        Share  : Long_Float;
        Shared : Long_Float := 0.0;
        begin
        for Index in 1 .. Brains.Neuron_Count (Model) loop
            if Brains.Neuron_Reach (Model, Index) > 0 then
                declare
                    Belief : constant Distributions.Distribution :=
                        Brains.Neuron_Opinion (Model, Index, Board, Position);
                    begin
                    for Candidate in Symbol range 1 .. Size loop
                        Share := Distributions.Probability_Of (Belief, Candidate);
                        if Share < Lowest (Candidate) then
                            Lowest (Candidate) := Share;
                            end if;
                        end loop;
                    end;
                end if;
            end loop;
        for Candidate in Symbol range 1 .. Size loop
            Shared := Shared + Lowest (Candidate);
            end loop;
        return Shared;
        end Shared_Bets;
    --# For each letter, the smallest bet any neuron places on it; then the sum.
    --# It is the part of their bets that all the neurons have in common.

    overriding function Readiness (
            Self     : in Agreement;
            Board    : in Canvases.Canvas;
            Model    : in Oracles.Oracle'Class;
            Position : in Positive
            ) return Long_Float is
        pragma Unreferenced (Self);
        begin
        if Model not in Brains.Brain'Class then
            return Certainty_Of (Board, Model, Position);
            end if;
        if Looking_Count (Brains.Brain'Class (Model)) < 2 then
            return Certainty_Of (Board, Model, Position);
            end if;
        return Shared_Bets (Brains.Brain'Class (Model), Board, Position);
        end Readiness;

    overriding function Readiness (
            Self     : in Leftmost;
            Board    : in Canvases.Canvas;
            Model    : in Oracles.Oracle'Class;
            Position : in Positive
            ) return Long_Float is
        pragma Unreferenced (Self, Model);
        begin
        return 1.0 - Long_Float (Position - 1) / Long_Float (Canvases.Length (Board));
        end Readiness;

    procedure Add_Part (
            Self   : in out Mixed;
            Part   : in     Criterion'Class;
            Weight : in     Long_Float := 1.0
            ) is
        begin
        Self.Parts.Append (Part);
        Self.Weights.Append (Weight);
        end Add_Part;

    overriding function Readiness (
            Self     : in Mixed;
            Board    : in Canvases.Canvas;
            Model    : in Oracles.Oracle'Class;
            Position : in Positive
            ) return Long_Float is
        Total      : Long_Float := 0.0;
        Weight_Sum : Long_Float := 0.0;
        Weight     : Long_Float;
        Ready      : Long_Float;
        begin
        for Index in 1 .. Natural (Self.Parts.Length) loop
            Weight := Self.Weights.Element (Index);
            Ready := Self.Parts (Index).Readiness (Board, Model, Position);
            Total := Total + Weight * Ready;
            Weight_Sum := Weight_Sum + Weight;
            end loop;
        if Weight_Sum <= 0.0 then
            return 0.0;
            end if;
        return Total / Weight_Sum;
        end Readiness;

    end Calipso.Criteria;
