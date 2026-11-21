with Colapso.Collapsing;
with Colapso.Distributions;

package body Colapso.Repairing is

    use type Canvases.Cell_State;

    function Is_Guess (
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Boolean is
        begin
        return Canvases.State_At (Board, Position) = Canvases.Guessed;
        end Is_Guess;

    function Is_Influenced (
            Board    : in Canvases.Canvas;
            Position : in Positive;
            Reach    : in Natural
            ) return Boolean is
        First : constant Integer := Integer'Max (1, Position - Reach);
        Last  : constant Integer := Integer'Min (Canvases.Length (Board), Position + Reach);
        begin
        for Neighbour in First .. Last loop
            if Is_Guess (Board, Neighbour) then
                return True;
                end if;
            end loop;
        return False;
        end Is_Influenced;
    --# ¿Hay alguna letra decidida por el modelo al alcance de esta celda?

    function Is_Measured (
            Board    : in Canvases.Canvas;
            Position : in Positive;
            Reach    : in Natural
            ) return Boolean is
        begin
        if Canvases.Is_Blank (Board, Position) then
            return False;
            end if;
        return Is_Influenced (Board, Position, Reach);
        end Is_Measured;

    function Surprise_At (
            Board    : in Canvases.Canvas;
            Model    : in Oracles.Oracle'Class;
            Position : in Positive
            ) return Long_Float is
        Belief : constant Distributions.Distribution := Model.Opinion (Board, Position);
        Actual : constant Symbol := Canvases.Symbol_At (Board, Position);
        begin
        return Distributions.Surprise_Of (Belief, Actual);
        end Surprise_At;

    function Tension (
            Board     : in Canvases.Canvas;
            Model     : in Oracles.Oracle'Class;
            Tolerance : in Long_Float
            ) return Long_Float is
        Model_Reach : constant Natural := Model.Reach;
        Result      : Long_Float := 0.0;
        Surprise    : Long_Float;
        begin
        for Position in 1 .. Canvases.Length (Board) loop
            if Is_Measured (Board, Position, Model_Reach) then
                Surprise := Surprise_At (Board, Model, Position);
                if Surprise > Tolerance then
                    Result := Result + (Surprise - Tolerance);
                    end if;
                end if;
            end loop;
        return Result;
        end Tension;

    function Most_Surprising_Cell (
            Board : in Canvases.Canvas;
            Model : in Oracles.Oracle'Class
            ) return Natural is
        Model_Reach   : constant Natural := Model.Reach;
        Best          : Natural := 0;
        Best_Surprise : Long_Float := 0.0;
        Surprise      : Long_Float;
        begin
        for Position in 1 .. Canvases.Length (Board) loop
            if Is_Measured (Board, Position, Model_Reach) then
                Surprise := Surprise_At (Board, Model, Position);
                if Best = 0 or else Surprise > Best_Surprise then
                    Best := Position;
                    Best_Surprise := Surprise;
                    end if;
                end if;
            end loop;
        return Best;
        end Most_Surprising_Cell;

    function Nearest_Guess (
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Natural is
        Left  : Integer;
        Right : Integer;
        begin
        for Distance in 0 .. Canvases.Length (Board) - 1 loop
            Left := Position - Distance;
            Right := Position + Distance;
            if Left >= 1 and then Is_Guess (Board, Left) then
                return Left;
                end if;
            if Right <= Canvases.Length (Board) and then Is_Guess (Board, Right) then
                return Right;
                end if;
            end loop;
        return 0;
        end Nearest_Guess;
    --# La letra decidida por el modelo más cercana. A igual distancia, la de la izquierda.

    procedure Reopen_Around (
            Board  : in out Canvases.Canvas;
            Focus  : in     Positive;
            Radius : in     Natural
            ) is
        First : constant Integer := Integer'Max (1, Focus - Radius);
        Last  : constant Integer := Integer'Min (Canvases.Length (Board), Focus + Radius);
        begin
        for Position in First .. Last loop
            if Is_Guess (Board, Position) then
                Canvases.Erase (Board, Position);
                end if;
            end loop;
        end Reopen_Around;
    --# Vuelve a dejar como huecos las letras del modelo cercanas al foco. Las dadas no se tocan.

    procedure Widen_At (
            Board : in out Canvases.Canvas;
            Focus : in     Positive;
            Extra : in     Natural
            ) is
        begin
        for Repetition in 1 .. Extra loop
            Canvases.Insert_Blank (Board, Focus);
            end loop;
        end Widen_At;

    procedure Attempt_Repair (
            Board   : in out Canvases.Canvas;
            Model   : in     Oracles.Oracle'Class;
            Dice    : in out Random_Sources.Generator;
            Options : in     Settings;
            Focus   : in     Positive;
            Extra   : in     Natural;
            Current : in out Long_Float
            ) is
        Candidate         : Canvases.Canvas := Board;
        Candidate_Tension : Long_Float;
        begin
        Reopen_Around (Candidate, Focus, Options.Radius);
        Widen_At (Candidate, Focus, Extra);
        Collapsing.Collapse_All (Candidate, Model, Dice);
        Candidate_Tension := Tension (Candidate, Model, Options.Tolerance);
        if Candidate_Tension < Current then
            Board := Candidate;
            Current := Candidate_Tension;
            end if;
        end Attempt_Repair;
    --# Prueba un arreglo sobre una copia. Si baja la tensión, se queda; si no, se tira.

    function May_Grow (
            Board   : in Canvases.Canvas;
            Options : in Settings
            ) return Boolean is
        begin
        if not Options.Can_Grow then
            return False;
            end if;
        return Canvases.Length (Board) + Options.Extra_Cells <= Options.Max_Length;
        end May_Grow;

    procedure Relax (
            Board   : in out Canvases.Canvas;
            Model   : in     Oracles.Oracle'Class;
            Dice    : in out Random_Sources.Generator;
            Outcome :    out Report;
            Options : in     Settings := Default_Settings
            ) is
        Current : Long_Float := Tension (Board, Model, Options.Tolerance);
        Before  : Long_Float;
        Worst   : Natural;
        Focus   : Natural;
        begin
        Outcome := (others => <>);
        for Round in 1 .. Options.Max_Rounds loop
            exit when Current <= 0.0;
            Outcome.Rounds := Outcome.Rounds + 1;
            Worst := Most_Surprising_Cell (Board, Model);
            Focus := Nearest_Guess (Board, Worst);
            Before := Current;
            Attempt_Repair (Board, Model, Dice, Options, Focus, 0, Current);
            --# Primer intento: mismo sitio, otras letras.
            if Current < Before then
                Outcome.Reopenings := Outcome.Reopenings + 1;
            elsif May_Grow (Board, Options) then
                Attempt_Repair (Board, Model, Dice, Options, Focus, Options.Extra_Cells, Current);
                --# Segundo intento: más sitio.
                if Current < Before then
                    Outcome.Widenings := Outcome.Widenings + 1;
                    end if;
                end if;
            end loop;
        Outcome.Final_Tension := Current;
        end Relax;

    end Colapso.Repairing;
