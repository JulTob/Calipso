package body Colapso.Blind_Spots is

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

    end Colapso.Blind_Spots;
