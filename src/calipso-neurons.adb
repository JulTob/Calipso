package body Calipso.Neurons is

    function Is_Voter (
            Board    : in Canvases.Canvas;
            Position : in Positive;
            Offset   : in Integer
            ) return Boolean is
        Neighbour : constant Integer := Position + Offset;
        begin
        if Offset = 0 then
            return False;
            end if;
        if Neighbour < 1 then
            return False;
            end if;
        if Neighbour > Canvases.Length (Board) then
            return False;
            end if;
        return not Canvases.Is_Blank (Board, Neighbour);
        end Is_Voter;

    function Same (
            Left  : in Neuron'Class;
            Right : in Neuron'Class
            ) return Boolean is
        begin
        return Left = Right;
        end Same;

    end Calipso.Neurons;
