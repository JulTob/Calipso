with Calipso.Distributions;

package body Calipso.Collapsing is

    type Uncertainty_Note is record
        Is_Fresh : Boolean := False;
        Entropy  : Long_Float := 0.0;
        end record;
    --# A note of how much doubt there is about a hole, and whether the note is up to date.

    type Uncertainty_Notes is array (Positive range <>) of Uncertainty_Note;

    function Doubt_About (
            Board    : in Canvases.Canvas;
            Model    : in Oracles.Oracle'Class;
            Position : in Positive
            ) return Long_Float is
        Belief : constant Distributions.Distribution := Model.Opinion (Board, Position);
        begin
        return Distributions.Entropy (Belief);
        end Doubt_About;

    procedure Refresh (
            Notes : in out Uncertainty_Notes;
            Board : in     Canvases.Canvas;
            Model : in     Oracles.Oracle'Class
            ) is
        begin
        for Position in 1 .. Canvases.Length (Board) loop
            if Canvases.Is_Blank (Board, Position) and then not Notes (Position).Is_Fresh then
                Notes (Position).Entropy := Doubt_About (Board, Model, Position);
                Notes (Position).Is_Fresh := True;
                end if;
            end loop;
        end Refresh;
    --# Recomputes the doubt of the holes whose note is out of date.

    function Most_Certain_Blank (
            Notes : in Uncertainty_Notes;
            Board : in Canvases.Canvas
            ) return Natural is
        Best : Natural := 0;
        begin
        for Position in 1 .. Canvases.Length (Board) loop
            if Canvases.Is_Blank (Board, Position) then
                if Best = 0 then
                    Best := Position;
                elsif Notes (Position).Entropy < Notes (Best).Entropy then
                    Best := Position;
                    end if;
                end if;
            end loop;
        return Best;
        end Most_Certain_Blank;
    --# The hole with the least doubt. On a tie, the first one. 0 if there are no holes.

    function First_Blank (
            Board : in Canvases.Canvas
            ) return Natural is
        begin
        for Position in 1 .. Canvases.Length (Board) loop
            if Canvases.Is_Blank (Board, Position) then
                return Position;
                end if;
            end loop;
        return 0;
        end First_Blank;

    procedure Pick_Random_Blank (
            Board  : in     Canvases.Canvas;
            Dice   : in out Random_Sources.Generator;
            Target :    out Natural
            ) is
        Blank_Total : constant Natural := Canvases.Blank_Count (Board);
        Skip        : Natural;
        begin
        Target := 0;
        if Blank_Total = 0 then
            return;
            end if;
        Random_Sources.Draw_Index (Dice, Blank_Total, Skip);
        for Position in 1 .. Canvases.Length (Board) loop
            if Canvases.Is_Blank (Board, Position) then
                if Skip = 0 then
                    Target := Position;
                    return;
                    end if;
                Skip := Skip - 1;
                end if;
            end loop;
        end Pick_Random_Blank;

    procedure Choose_Target (
            Board  : in     Canvases.Canvas;
            Model  : in     Oracles.Oracle'Class;
            Dice   : in out Random_Sources.Generator;
            Order  : in     Visiting_Order;
            Notes  : in out Uncertainty_Notes;
            Target :    out Natural
            ) is
        begin
        case Order is
            when Most_Certain_First =>
                Refresh (Notes, Board, Model);
                Target := Most_Certain_Blank (Notes, Board);
            when Left_To_Right =>
                Target := First_Blank (Board);
            when At_Random =>
                Pick_Random_Blank (Board, Dice, Target);
            end case;
        end Choose_Target;

    procedure Collapse_Cell (
            Board    : in out Canvases.Canvas;
            Model    : in     Oracles.Oracle'Class;
            Dice     : in out Random_Sources.Generator;
            Rule     : in     Choice_Rule;
            Position : in     Positive
            ) is
        Belief : constant Distributions.Distribution := Model.Opinion (Board, Position);
        Unit   : Random_Sources.Unit_Fraction;
        Chosen : Symbol;
        begin
        case Rule is
            when Always_Most_Likely =>
                Chosen := Distributions.Most_Likely (Belief);
            when By_Chance =>
                Random_Sources.Draw_Unit (Dice, Unit);
                Chosen := Distributions.Sampled (Belief, Unit);
            end case;
        Canvases.Guess (Board, Position, Chosen);
        end Collapse_Cell;

    procedure Mark_Stale_Around (
            Notes    : in out Uncertainty_Notes;
            Position : in     Positive;
            Reach    : in     Natural
            ) is
        First : constant Integer := Integer'Max (Notes'First, Position - Reach);
        Last  : constant Integer := Integer'Min (Notes'Last, Position + Reach);
        begin
        for Neighbour in First .. Last loop
            Notes (Neighbour).Is_Fresh := False;
            end loop;
        end Mark_Stale_Around;
    --# Propagate: everything within reach of the collapsed cell must be recomputed.

    procedure Collapse_All (
            Board    : in out Canvases.Canvas;
            Model    : in     Oracles.Oracle'Class;
            Dice     : in out Random_Sources.Generator;
            Order    : in     Visiting_Order := Most_Certain_First;
            Rule     : in     Choice_Rule := By_Chance;
            Observer : access procedure (
                    Current  : in Canvases.Canvas;
                    Position : in Positive
                    ) := null
            ) is
        Notes  : Uncertainty_Notes (1 .. Canvases.Length (Board));
        Target : Natural;
        begin
        while Canvases.Blank_Count (Board) > 0 loop
            Choose_Target (Board, Model, Dice, Order, Notes, Target);
            Collapse_Cell (Board, Model, Dice, Rule, Target);
            Mark_Stale_Around (Notes, Target, Model.Reach);
            if Observer /= null then
                Observer (Board, Target);
                end if;
            end loop;
        end Collapse_All;

    type Readiness_Note is record
        Is_Fresh  : Boolean := False;
        Readiness : Long_Float := 0.0;
        end record;

    type Readiness_Notes is array (Positive range <>) of Readiness_Note;

    procedure Refresh_Readiness (
            Notes : in out Readiness_Notes;
            Board : in     Canvases.Canvas;
            Model : in     Oracles.Oracle'Class;
            Guide : in     Criteria.Criterion'Class
            ) is
        begin
        for Position in 1 .. Canvases.Length (Board) loop
            if Canvases.Is_Blank (Board, Position) and then not Notes (Position).Is_Fresh then
                Notes (Position).Readiness := Guide.Readiness (Board, Model, Position);
                Notes (Position).Is_Fresh := True;
                end if;
            end loop;
        end Refresh_Readiness;

    function Readiest_Blank (
            Notes : in Readiness_Notes;
            Board : in Canvases.Canvas
            ) return Natural is
        Best : Natural := 0;
        begin
        for Position in 1 .. Canvases.Length (Board) loop
            if Canvases.Is_Blank (Board, Position) then
                if Best = 0 then
                    Best := Position;
                elsif Notes (Position).Readiness > Notes (Best).Readiness then
                    Best := Position;
                    end if;
                end if;
            end loop;
        return Best;
        end Readiest_Blank;
    --# The readiest hole. On a tie, the first one. 0 if there are no holes.

    procedure Mark_Readiness_Stale (
            Notes    : in out Readiness_Notes;
            Position : in     Positive;
            Reach    : in     Natural
            ) is
        First : constant Integer := Integer'Max (Notes'First, Position - Reach);
        Last  : constant Integer := Integer'Min (Notes'Last, Position + Reach);
        begin
        for Neighbour in First .. Last loop
            Notes (Neighbour).Is_Fresh := False;
            end loop;
        end Mark_Readiness_Stale;

    procedure Collapse_By (
            Board    : in out Canvases.Canvas;
            Model    : in     Oracles.Oracle'Class;
            Dice     : in out Random_Sources.Generator;
            Guide    : in     Criteria.Criterion'Class;
            Rule     : in     Choice_Rule := By_Chance;
            Observer : access procedure (
                    Current  : in Canvases.Canvas;
                    Position : in Positive
                    ) := null
            ) is
        Notes  : Readiness_Notes (1 .. Canvases.Length (Board));
        Target : Natural;
        begin
        while Canvases.Blank_Count (Board) > 0 loop
            Refresh_Readiness (Notes, Board, Model, Guide);
            Target := Readiest_Blank (Notes, Board);
            Collapse_Cell (Board, Model, Dice, Rule, Target);
            Mark_Readiness_Stale (Notes, Target, Model.Reach);
            if Observer /= null then
                Observer (Board, Target);
                end if;
            end loop;
        end Collapse_By;

    end Calipso.Collapsing;
