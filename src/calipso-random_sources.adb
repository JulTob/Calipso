package body Calipso.Random_Sources is

    use type Interfaces.Unsigned_64;

    Multiplier : constant Interfaces.Unsigned_64 := 6364136223846793005;
    Increment  : constant Interfaces.Unsigned_64 := 1442695040888963407;
    --# Constants of Knuth's linear congruential generator (MMIX).
    --# Rule: new state = state * Multiplier + Increment.
    --# The type is modular, 64 bits: on overflow it "wraps around" by itself.

    Two_To_53 : constant Long_Float := 2.0 ** 53;

    function Seeded (
            Seed : in Natural
            ) return Generator is
        Result : Generator;
        begin
        Result.State := Interfaces.Unsigned_64 (Seed);
        return Result;
        end Seeded;

    procedure Draw_Unit (
            Source : in out Generator;
            Unit   :    out Unit_Fraction
            ) is
        Top_Bits : Interfaces.Unsigned_64;
        begin
        Source.State := Source.State * Multiplier;
        Source.State := Source.State + Increment;
        Top_Bits := Interfaces.Shift_Right (Source.State, 11);
        --# We keep the top 53 bits: those are the ones that fit exactly in a Long_Float.
        Unit := Long_Float (Top_Bits) / Two_To_53;
        end Draw_Unit;

    procedure Draw_Index (
            Source : in out Generator;
            Below  : in     Positive;
            Index  :    out Natural
            ) is
        Unit   : Unit_Fraction;
        Scaled : Long_Float;
        begin
        Draw_Unit (Source, Unit);
        Scaled := Unit * Long_Float (Below);
        Index := Natural (Long_Float'Floor (Scaled));
        --# Careful: converting a real to an integer in Ada ROUNDS. That is why 'Floor comes first.
        if Index >= Below then
            Index := Below - 1;
            end if;
        end Draw_Index;

    end Calipso.Random_Sources;
