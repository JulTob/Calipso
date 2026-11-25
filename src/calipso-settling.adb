with Calipso.Distributions;

package body Calipso.Settling is

    use type Canvases.Cell_State;

    function Written (
            Text : in Texts.Symbol_Text
            ) return Canvases.Canvas is
        Board : Canvases.Canvas;
        begin
        for Value of Text loop
            Canvases.Append_Blank (Board);
            Canvases.Guess (Board, Canvases.Length (Board), Value);
            end loop;
        return Board;
        end Written;

    function Even_Anchors (
            Text : in Texts.Symbol_Text;
            Sure : in Certainties.Certainty
            ) return Anchored_Oracles.Anchor_List is
        Anchors : Anchored_Oracles.Anchor_List;
        begin
        for Value of Text loop
            Anchors.Append (Anchored_Oracles.Anchor_Of (Value, Sure));
            end loop;
        return Anchors;
        end Even_Anchors;

    procedure Revisit (
            Board    : in out Canvases.Canvas;
            Model    : in     Oracles.Oracle'Class;
            Position : in     Positive;
            Changed  :    out Boolean
            ) is
        Best : constant Symbol := Distributions.Most_Likely (Model.Opinion (Board, Position));
        begin
        Changed := Best /= Canvases.Symbol_At (Board, Position);
        if Changed then
            Canvases.Erase (Board, Position);
            Canvases.Guess (Board, Position, Best);
            end if;
        end Revisit;
    --# One cell decides again.

    procedure Read_Once (
            Board   : in out Canvases.Canvas;
            Model   : in     Oracles.Oracle'Class;
            Changes :    out Natural
            ) is
        Changed : Boolean;
        begin
        Changes := 0;
        for Position in 1 .. Canvases.Length (Board) loop
            if Canvases.State_At (Board, Position) = Canvases.Guessed then
                Revisit (Board, Model, Position, Changed);
                if Changed then
                    Changes := Changes + 1;
                    end if;
                end if;
            end loop;
        end Read_Once;
    --# One reading from left to right. Changes says how many cells were rewritten.

    procedure Settle (
            Board   : in out Canvases.Canvas;
            Model   : in     Oracles.Oracle'Class;
            Anchors : in     Anchored_Oracles.Anchor_List;
            Outcome :    out Report;
            Passes  : in     Positive := Default_Passes
            ) is
        Anchored : Anchored_Oracles.Anchored_Oracle (Model'Access);
        Changes  : Natural;
        begin
        Anchored.Anchors := Anchors;
        Outcome := (Passes => 0, Changes => 0, Is_Settled => False);
        for Pass in 1 .. Passes loop
            Read_Once (Board, Anchored, Changes);
            Outcome.Passes := Outcome.Passes + 1;
            Outcome.Changes := Outcome.Changes + Changes;
            if Changes = 0 then
                Outcome.Is_Settled := True;
                exit;
                end if;
            end loop;
        end Settle;

    end Calipso.Settling;
