with Ada.Numerics.Long_Elementary_Functions;

package body Calipso.Counting_Neurons is

    package Math renames Ada.Numerics.Long_Elementary_Functions;

    procedure Prepare (
            Self         : in out Counting_Neuron;
            Letter_Count : in     Symbol;
            Longest      : in     Positive := Counting_Oracles.Default_Longest;
            Capacity     : in     Natural := 0
            ) is
        begin
        Counting_Oracles.Prepare (Self.Oracle, Letter_Count, Longest, Capacity);
        end Prepare;

    overriding function Name (
            Self : in Counting_Neuron
            ) return String is
        begin
        if Counting_Oracles.Capacity (Self.Oracle) > 0 then
            return "memory";
            --# The same neuron with bounded memory goes by another name in recipes.
            end if;
        return "counting";
        end Name;

    overriding function Kind (
            Self : in Counting_Neuron
            ) return String is
        pragma Unreferenced (Self);
        begin
        return "counting";
        end Kind;

    overriding function Reach (
            Self : in Counting_Neuron
            ) return Natural is
        begin
        return Counting_Oracles.Reach (Self.Oracle);
        end Reach;

    overriding procedure Add_Scores (
            Self     : in     Counting_Neuron;
            Board    : in     Canvases.Canvas;
            Position : in     Positive;
            Strength : in     Long_Float;
            Scores   : in out Distributions.Score_Array
            ) is
        Belief  : constant Distributions.Distribution :=
            Counting_Oracles.Opinion (Self.Oracle, Board, Position);
        Share   : Long_Float;
        Floored : Long_Float;
        begin
        for Candidate in Symbol range 1 .. Belief.Size loop
            Share := Distributions.Probability_Of (Belief, Candidate);
            Floored := Long_Float'Max (Share, Distributions.Smallest_Probability);
            Scores (Candidate) := Scores (Candidate) + Strength * Math.Log (Floored);
            end loop;
        end Add_Scores;

    overriding procedure Learn_From_Text (
            Self  : in out Counting_Neuron;
            Piece : in     Texts.Symbol_Text
            ) is
        begin
        Counting_Oracles.Study (Self.Oracle, Piece);
        end Learn_From_Text;

    overriding procedure Save (
            Self : in Counting_Neuron;
            File : in Ada.Text_IO.File_Type
            ) is
        begin
        Counting_Oracles.Save (Self.Oracle, File);
        end Save;

    overriding procedure Load (
            Self : in out Counting_Neuron;
            File : in     Ada.Text_IO.File_Type
            ) is
        begin
        Counting_Oracles.Load (Self.Oracle, File);
        end Load;

    end Calipso.Counting_Neurons;
