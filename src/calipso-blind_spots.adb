with Calipso.Distributions;
with Calipso.Templates;

package body Calipso.Blind_Spots is

    use type Canvases.Cell_State;

    procedure Hide_At_Random (
            Board : in out Canvases.Canvas;
            Rate  : in     Random_Sources.Unit_Fraction;
            Dice  : in out Random_Sources.Generator
            ) is
        Unit : Random_Sources.Unit_Fraction;
        begin
        for Position in 1 .. Canvases.Length (Board) loop
            if Canvases.State_At (Board, Position) = Canvases.Given then
                Random_Sources.Draw_Unit (Dice, Unit);
                if Unit < Rate then
                    Canvases.Hide (Board, Position);
                    end if;
                end if;
            end loop;
        end Hide_At_Random;

    function Scored (
            Filled   : in Canvases.Canvas;
            Original : in Canvases.Canvas
            ) return Score is
        Result : Score;
        begin
        for Position in 1 .. Canvases.Length (Filled) loop
            if Canvases.State_At (Filled, Position) = Canvases.Guessed then
                Result.Hidden := Result.Hidden + 1;
                if Canvases.Symbol_At (Filled, Position) = Canvases.Symbol_At (Original, Position) then
                    Result.Recovered := Result.Recovered + 1;
                    end if;
                end if;
            end loop;
        return Result;
        end Scored;

    function "+" (
            Left  : in Exam_Result;
            Right : in Exam_Result
            ) return Exam_Result is
        begin
        return (
            Hidden       => Left.Hidden + Right.Hidden,
            Hits         => Left.Hits + Right.Hits,
            Surprise_Sum => Left.Surprise_Sum + Right.Surprise_Sum
            );
        end "+";

    function Mean_Surprise (
            Result : in Exam_Result
            ) return Long_Float is
        begin
        if Result.Hidden = 0 then
            return 0.0;
            end if;
        return Result.Surprise_Sum / Long_Float (Result.Hidden);
        end Mean_Surprise;

    procedure Grade_Cell (
            Model    : in     Oracles.Oracle'Class;
            Board    : in     Canvases.Canvas;
            Position : in     Positive;
            Actual   : in     Symbol;
            Result   : in out Exam_Result
            ) is
        Belief : constant Distributions.Distribution := Model.Opinion (Board, Position);
        begin
        Result.Hidden := Result.Hidden + 1;
        Result.Surprise_Sum := Result.Surprise_Sum + Distributions.Surprise_Of (Belief, Actual);
        if Distributions.Most_Likely (Belief) = Actual then
            Result.Hits := Result.Hits + 1;
            end if;
        end Grade_Cell;

    procedure Examine (
            Model        : in     Oracles.Oracle'Class;
            Text         : in     Texts.Symbol_Text;
            Dice         : in out Random_Sources.Generator;
            Pieces       : in     Natural;
            Piece_Length : in     Positive;
            Rate         : in     Random_Sources.Unit_Fraction;
            Result       :    out Exam_Result
            ) is
        Room   : constant Positive := Natural (Text.Length) - Piece_Length;
        Start  : Natural;
        Actual : Symbol;
        begin
        Result := (others => <>);
        for Piece in 1 .. Pieces loop
            Random_Sources.Draw_Index (Dice, Room, Start);
            declare
                Original : constant Canvases.Canvas := Templates.From_Text (Text, Start + 1, Piece_Length);
                Board    : Canvases.Canvas := Original;
                begin
                Hide_At_Random (Board, Rate, Dice);
                for Position in 1 .. Piece_Length loop
                    if Canvases.Is_Blank (Board, Position) then
                        Actual := Canvases.Symbol_At (Original, Position);
                        Grade_Cell (Model, Board, Position, Actual, Result);
                        end if;
                    end loop;
                end;
            end loop;
        end Examine;

    end Calipso.Blind_Spots;
