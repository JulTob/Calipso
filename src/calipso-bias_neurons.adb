with Calipso.Records;

package body Calipso.Bias_Neurons is

    procedure Prepare (
            Self         : in out Bias_Neuron;
            Letter_Count : in     Symbol
            ) is
        begin
        Self.Letter_Count := Letter_Count;
        Self.Points := Numbers.Zeros (Natural (Letter_Count));
        end Prepare;

    overriding function Name (
            Self : in Bias_Neuron
            ) return String is
        pragma Unreferenced (Self);
        begin
        return "bias";
        end Name;

    overriding function Kind (
            Self : in Bias_Neuron
            ) return String is
        pragma Unreferenced (Self);
        begin
        return "bias";
        end Kind;

    overriding function Reach (
            Self : in Bias_Neuron
            ) return Natural is
        pragma Unreferenced (Self);
        begin
        return 0;
        end Reach;

    overriding procedure Add_Scores (
            Self     : in     Bias_Neuron;
            Board    : in     Canvases.Canvas;
            Position : in     Positive;
            Strength : in     Long_Float;
            Scores   : in out Distributions.Score_Array
            ) is
        pragma Unreferenced (Board, Position);
        begin
        for Candidate in Symbol range 1 .. Self.Letter_Count loop
            Scores (Candidate) := Scores (Candidate) + Strength * Self.Points.Element (Positive (Candidate));
            end loop;
        end Add_Scores;

    overriding procedure Learn_From_Cell (
            Self     : in out Bias_Neuron;
            Board    : in     Canvases.Canvas;
            Position : in     Positive;
            Errors   : in     Distributions.Score_Array;
            Step     : in     Long_Float
            ) is
        pragma Unreferenced (Board, Position);
        Before : Long_Float;
        begin
        for Candidate in Symbol range 1 .. Self.Letter_Count loop
            Before := Self.Points.Element (Positive (Candidate));
            Self.Points.Replace_Element (Positive (Candidate), Before - Step * Errors (Candidate));
            end loop;
        end Learn_From_Cell;

    overriding procedure Save (
            Self : in Bias_Neuron;
            File : in Ada.Text_IO.File_Type
            ) is
        begin
        Records.Write_Count (File, Natural (Self.Letter_Count));
        Records.Write_Reals (File, Self.Points);
        end Save;

    overriding procedure Load (
            Self : in out Bias_Neuron;
            File : in     Ada.Text_IO.File_Type
            ) is
        begin
        Self.Letter_Count := Symbol (Records.Read_Count (File));
        Self.Points := Records.Read_Reals (File);
        end Load;

    end Calipso.Bias_Neurons;
