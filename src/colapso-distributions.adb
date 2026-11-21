with Ada.Numerics.Long_Elementary_Functions;

package body Colapso.Distributions is

    package Math renames Ada.Numerics.Long_Elementary_Functions;

    function Zero (
            Size : in Symbol
            ) return Distribution is
        Result : constant Distribution (Size) := (Size => Size, Weights => (others => 0.0));
        begin
        return Result;
        end Zero;

    function Uniform (
            Size : in Symbol
            ) return Distribution is
        Share  : constant Weight := 1.0 / Long_Float (Size);
        Result : constant Distribution (Size) := (Size => Size, Weights => (others => Share));
        begin
        return Result;
        end Uniform;

    function From_Scores (
            Scores : in Score_Array
            ) return Distribution is
        Highest : Long_Float := Scores (1);
        Raw     : Distribution (Scores'Last);
        begin
        for Value in Symbol range 2 .. Scores'Last loop
            if Scores (Value) > Highest then
                Highest := Scores (Value);
                end if;
            end loop;
        for Value in Symbol range 1 .. Scores'Last loop
            Raw.Weights (Value) := Math.Exp (Scores (Value) - Highest);
            --# Restar el máximo no cambia el resultado y evita números enormes.
            end loop;
        return Normalized (Raw);
        end From_Scores;

    function Weight_Of (
            Item  : in Distribution;
            Value : in Symbol
            ) return Weight is
        begin
        return Item.Weights (Value);
        end Weight_Of;

    procedure Set_Weight (
            Item   : in out Distribution;
            Value  : in     Symbol;
            Amount : in     Weight
            ) is
        begin
        Item.Weights (Value) := Amount;
        end Set_Weight;

    function Total (
            Item : in Distribution
            ) return Weight is
        Result : Weight := 0.0;
        begin
        for Value in Symbol range 1 .. Item.Size loop
            Result := Result + Item.Weights (Value);
            end loop;
        return Result;
        end Total;

    function Variety (
            Item : in Distribution
            ) return Natural is
        Result : Natural := 0;
        begin
        for Value in Symbol range 1 .. Item.Size loop
            if Item.Weights (Value) > 0.0 then
                Result := Result + 1;
                end if;
            end loop;
        return Result;
        end Variety;

    function "+" (
            Left  : in Distribution;
            Right : in Distribution
            ) return Distribution is
        Result : Distribution (Left.Size);
        begin
        for Value in Symbol range 1 .. Left.Size loop
            Result.Weights (Value) := Left.Weights (Value) + Right.Weights (Value);
            end loop;
        return Result;
        end "+";

    function "*" (
            Factor : in Weight;
            Right  : in Distribution
            ) return Distribution is
        Result : Distribution (Right.Size);
        begin
        for Value in Symbol range 1 .. Right.Size loop
            Result.Weights (Value) := Factor * Right.Weights (Value);
            end loop;
        return Result;
        end "*";

    function Normalized (
            Item : in Distribution
            ) return Distribution is
        Sum    : constant Weight := Total (Item);
        Result : Distribution (Item.Size);
        begin
        for Value in Symbol range 1 .. Item.Size loop
            Result.Weights (Value) := Item.Weights (Value) / Sum;
            end loop;
        return Result;
        end Normalized;

    function Probability_Of (
            Item  : in Distribution;
            Value : in Symbol
            ) return Long_Float is
        Sum : constant Weight := Total (Item);
        begin
        return Item.Weights (Value) / Sum;
        end Probability_Of;

    function Entropy (
            Item : in Distribution
            ) return Long_Float is
        Sum    : constant Weight := Total (Item);
        Share  : Long_Float;
        Result : Long_Float := 0.0;
        begin
        for Value in Symbol range 1 .. Item.Size loop
            Share := Item.Weights (Value) / Sum;
            if Share > 0.0 then
                Result := Result - Share * Math.Log (Share);
                end if;
            end loop;
        return Result;
        end Entropy;

    function Surprise_Of (
            Item  : in Distribution;
            Value : in Symbol
            ) return Long_Float is
        Share   : constant Long_Float := Probability_Of (Item, Value);
        Floored : constant Long_Float := Long_Float'Max (Share, Smallest_Probability);
        begin
        return -Math.Log (Floored);
        end Surprise_Of;

    function Most_Likely (
            Item : in Distribution
            ) return Symbol is
        Best : Symbol := 1;
        begin
        for Value in Symbol range 2 .. Item.Size loop
            if Item.Weights (Value) > Item.Weights (Best) then
                Best := Value;
                end if;
            end loop;
        return Best;
        end Most_Likely;

    function Sampled (
            Item : in Distribution;
            Unit : in Long_Float
            ) return Symbol is
        Target        : constant Long_Float := Unit * Total (Item);
        Running       : Long_Float := 0.0;
        Last_Possible : Symbol := 1;
        begin
        for Value in Symbol range 1 .. Item.Size loop
            if Item.Weights (Value) > 0.0 then
                Last_Possible := Value;
                Running := Running + Item.Weights (Value);
                if Target < Running then
                    return Value;
                    end if;
                end if;
            end loop;
        return Last_Possible;
        --# Solo se llega aquí por redondeo: devolvemos la última letra posible.
        end Sampled;

    end Colapso.Distributions;
