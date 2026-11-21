with Ada.Numerics;
with Ada.Numerics.Long_Elementary_Functions;

with Calipso.Records;

package body Calipso.Basis_Neurons is

    package Math renames Ada.Numerics.Long_Elementary_Functions;

    Two_Pi : constant Long_Float := 2.0 * Ada.Numerics.Pi;

    function Word_Of (
            Measure : in Basis_Kind
            ) return String is
        begin
        case Measure is
            when By_Position =>
                return "position";
            when By_Harmonic =>
                return "harmonic";
            when By_Decay =>
                return "decay";
            end case;
        end Word_Of;

    function Measure_Of (
            Word : in String
            ) return Basis_Kind is
        begin
        for Measure in Basis_Kind loop
            if Word_Of (Measure) = Word then
                return Measure;
                end if;
            end loop;
        raise Records.Record_Error with "unknown kind of basis: " & Word;
        end Measure_Of;

    function Basis_Slot (
            Self   : in Basis_Neuron;
            Curve  : in Positive;
            Offset : in Integer
            ) return Positive is
        Width : constant Positive := 2 * Self.Vote_Reach + 1;
        begin
        return (Curve - 1) * Width + (Offset + Self.Vote_Reach) + 1;
        end Basis_Slot;

    function Vote_Slot (
            Self      : in Basis_Neuron;
            Curve     : in Positive;
            Neighbour : in Symbol;
            Candidate : in Symbol
            ) return Positive is
        Letters : constant Positive := Positive (Self.Letter_Count);
        Row     : constant Natural := (Curve - 1) * Letters + (Natural (Neighbour) - 1);
        begin
        return Row * Letters + (Natural (Candidate) - 1) + 1;
        end Vote_Slot;

    function Curve_Total (
            Measure : in Basis_Kind;
            Reach   : in Positive;
            Detail  : in Natural
            ) return Natural is
        begin
        case Measure is
            when By_Position =>
                return 2 * Reach;
            when By_Harmonic =>
                return 2 * Detail + 1;
            when By_Decay =>
                return 2 * Detail;
            end case;
        end Curve_Total;

    procedure Fill_Position (
            Self : in out Basis_Neuron
            ) is
        Reach : constant Positive := Self.Vote_Reach;
        begin
        for Offset in -Reach .. -1 loop
            Self.Basis.Replace_Element (Basis_Slot (Self, Offset + Reach + 1, Offset), 1.0);
            end loop;
        for Offset in 1 .. Reach loop
            Self.Basis.Replace_Element (Basis_Slot (Self, Offset + Reach, Offset), 1.0);
            end loop;
        end Fill_Position;
    --# Curve number c is 1 at one exact distance and 0 everywhere else.

    procedure Fill_Harmonic (
            Self : in out Basis_Neuron
            ) is
        Reach : constant Positive := Self.Vote_Reach;
        Width : constant Positive := 2 * Reach + 1;
        Angle : Long_Float;
        begin
        for Offset in -Reach .. Reach loop
            Self.Basis.Replace_Element (Basis_Slot (Self, 1, Offset), 1.0);
            for Wave in 1 .. Self.Detail loop
                Angle := Two_Pi * Long_Float (Wave * Offset) / Long_Float (Width);
                Self.Basis.Replace_Element (Basis_Slot (Self, 2 * Wave, Offset), Math.Cos (Angle));
                Self.Basis.Replace_Element (Basis_Slot (Self, 2 * Wave + 1, Offset), Math.Sin (Angle));
                end loop;
            end loop;
        end Fill_Harmonic;
    --# Curve 1 is flat. Then, for each wave: a cosine and a sine with that many cycles across the window.

    procedure Fill_Decay (
            Self : in out Basis_Neuron
            ) is
        Rate   : Long_Float := 1.0;
        Height : Long_Float;
        begin
        for Speed in 1 .. Self.Detail loop
            for Distance in 1 .. Self.Vote_Reach loop
                Height := Math.Exp (-Rate * Long_Float (Distance - 1));
                Self.Basis.Replace_Element (Basis_Slot (Self, Speed, -Distance), Height);
                Self.Basis.Replace_Element (Basis_Slot (Self, Self.Detail + Speed, Distance), Height);
                end loop;
            Rate := Rate / 2.0;
            end loop;
        end Fill_Decay;
    --# Fading speeds 1, 1/2, 1/4... The nearest neighbour always counts 1.
    --# Curves 1 .. Detail look left; curves Detail + 1 .. 2 * Detail look right.

    procedure Prepare (
            Self         : in out Basis_Neuron;
            Letter_Count : in     Symbol;
            Measure      : in     Basis_Kind;
            Reach        : in     Positive;
            Detail       : in     Natural
            ) is
        Letters : constant Positive := Positive (Letter_Count);
        Width   : constant Positive := 2 * Reach + 1;
        begin
        Self.Letter_Count := Letter_Count;
        Self.Vote_Reach := Reach;
        Self.Measure := Measure;
        Self.Detail := Detail;
        Self.Curve_Count := Curve_Total (Measure, Reach, Detail);
        Self.Basis := Numbers.Zeros (Self.Curve_Count * Width);
        case Measure is
            when By_Position =>
                Fill_Position (Self);
            when By_Harmonic =>
                Fill_Harmonic (Self);
            when By_Decay =>
                Fill_Decay (Self);
            end case;
        Self.Votes := Numbers.Zeros (Self.Curve_Count * Letters * Letters);
        end Prepare;

    function Curve_Height (
            Self   : in Basis_Neuron;
            Curve  : in Positive;
            Offset : in Integer
            ) return Long_Float is
        begin
        return Self.Basis.Element (Basis_Slot (Self, Curve, Offset));
        end Curve_Height;

    overriding function Name (
            Self : in Basis_Neuron
            ) return String is
        begin
        if Self.Measure = By_Harmonic and then Self.Detail = 0 then
            return "presence";
            end if;
        return Word_Of (Self.Measure);
        end Name;

    overriding function Kind (
            Self : in Basis_Neuron
            ) return String is
        pragma Unreferenced (Self);
        begin
        return "basis";
        end Kind;

    overriding function Reach (
            Self : in Basis_Neuron
            ) return Natural is
        begin
        return Self.Vote_Reach;
        end Reach;

    overriding procedure Add_Scores (
            Self     : in     Basis_Neuron;
            Board    : in     Canvases.Canvas;
            Position : in     Positive;
            Strength : in     Long_Float;
            Scores   : in out Distributions.Score_Array
            ) is
        Neighbour : Symbol;
        Height    : Long_Float;
        Factor    : Long_Float;
        First     : Positive;
        Slot      : Positive;
        begin
        for Offset in -Self.Vote_Reach .. Self.Vote_Reach loop
            if Neurons.Is_Voter (Board, Position, Offset) then
                Neighbour := Canvases.Symbol_At (Board, Position + Offset);
                for Curve in 1 .. Self.Curve_Count loop
                    Height := Curve_Height (Self, Curve, Offset);
                    if Height /= 0.0 then
                        Factor := Strength * Height;
                        First := Vote_Slot (Self, Curve, Neighbour, 1);
                        for Candidate in Symbol range 1 .. Self.Letter_Count loop
                            Slot := First + Positive (Candidate) - 1;
                            Scores (Candidate) := Scores (Candidate) + Factor * Self.Votes.Element (Slot);
                            end loop;
                        end if;
                    end loop;
                end if;
            end loop;
        end Add_Scores;

    overriding procedure Learn_From_Cell (
            Self     : in out Basis_Neuron;
            Board    : in     Canvases.Canvas;
            Position : in     Positive;
            Errors   : in     Distributions.Score_Array;
            Step     : in     Long_Float
            ) is
        Neighbour : Symbol;
        Height    : Long_Float;
        Factor    : Long_Float;
        First     : Positive;
        Slot      : Positive;
        Before    : Long_Float;
        begin
        for Offset in -Self.Vote_Reach .. Self.Vote_Reach loop
            if Neurons.Is_Voter (Board, Position, Offset) then
                Neighbour := Canvases.Symbol_At (Board, Position + Offset);
                for Curve in 1 .. Self.Curve_Count loop
                    Height := Curve_Height (Self, Curve, Offset);
                    if Height /= 0.0 then
                        Factor := Step * Height;
                        --# A vote is corrected in proportion to how loudly it spoke.
                        First := Vote_Slot (Self, Curve, Neighbour, 1);
                        for Candidate in Symbol range 1 .. Self.Letter_Count loop
                            Slot := First + Positive (Candidate) - 1;
                            Before := Self.Votes.Element (Slot);
                            Self.Votes.Replace_Element (Slot, Before - Factor * Errors (Candidate));
                            end loop;
                        end if;
                    end loop;
                end if;
            end loop;
        end Learn_From_Cell;

    overriding procedure Save (
            Self : in Basis_Neuron;
            File : in Ada.Text_IO.File_Type
            ) is
        begin
        Records.Write_Word (File, Word_Of (Self.Measure));
        Records.Write_Count (File, Natural (Self.Letter_Count));
        Records.Write_Count (File, Self.Vote_Reach);
        Records.Write_Count (File, Self.Detail);
        Records.Write_Reals (File, Self.Votes);
        end Save;

    overriding procedure Load (
            Self : in out Basis_Neuron;
            File : in     Ada.Text_IO.File_Type
            ) is
        Word         : constant String := Records.Read_Word (File);
        Letter_Count : constant Natural := Records.Read_Count (File);
        Reach        : constant Natural := Records.Read_Count (File);
        Detail       : constant Natural := Records.Read_Count (File);
        begin
        Prepare (Self, Symbol (Letter_Count), Measure_Of (Word), Reach, Detail);
        Self.Votes := Records.Read_Reals (File);
        end Load;

    end Calipso.Basis_Neurons;
