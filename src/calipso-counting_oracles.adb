package body Calipso.Counting_Oracles is

    use type Distributions.Distribution;
    --# Makes the "+" and "*" operators of the distribution algebra visible.

    subtype Direction is Integer range -1 .. 1;
    To_The_Left  : constant Direction := -1;
    To_The_Right : constant Direction := 1;

    function Known_Run (
            Board    : in Canvases.Canvas;
            Position : in Positive;
            Side     : in Direction;
            Limit    : in Natural
            ) return Natural is
        Run       : Natural := 0;
        Neighbour : Integer;
        begin
        while Run < Limit loop
            Neighbour := Position + Side * (Run + 1);
            exit when Neighbour < 1;
            exit when Neighbour > Canvases.Length (Board);
            exit when Canvases.Is_Blank (Board, Neighbour);
            Run := Run + 1;
            end loop;
        return Run;
        end Known_Run;
    --# How many cells with a letter sit right next to the hole, towards one side.

    function Should_Widen_Left (
            Can_Left   : in Boolean;
            Can_Right  : in Boolean;
            Left_Used  : in Natural;
            Right_Used : in Natural
            ) return Boolean is
        begin
        if not Can_Left then
            return False;
            end if;
        if not Can_Right then
            return True;
            end if;
        return Left_Used <= Right_Used;
        end Should_Widen_Left;
    --# Alternate sides; if only one side is possible, use that one.

    function Evidence (
            Self       : in Counting_Oracle;
            Board      : in Canvases.Canvas;
            Position   : in Positive;
            Left_Used  : in Natural;
            Right_Used : in Natural
            ) return Distributions.Distribution is
        Hole   : constant Positive := Left_Used + 1;
        Window : Fragment_Counts.Fragment (1 .. Left_Used + 1 + Right_Used) := (others => Unknown);
        Clue   : Distributions.Distribution := Distributions.Zero (Self.Letter_Count);
        Seen   : Natural;
        begin
        for Offset in 1 .. Left_Used loop
            Window (Hole - Offset) := Canvases.Symbol_At (Board, Position - Offset);
            end loop;
        for Offset in 1 .. Right_Used loop
            Window (Hole + Offset) := Canvases.Symbol_At (Board, Position + Offset);
            end loop;
        for Candidate in Symbol range 1 .. Self.Letter_Count loop
            Window (Hole) := Candidate;
            Seen := Fragment_Counts.Count_Of (Self.Table, Window);
            Distributions.Set_Weight (Clue, Candidate, Long_Float (Seen));
            end loop;
        return Clue;
        end Evidence;
    --# For each candidate letter: how many times the window was seen with that letter in the hole.

    function Updated (
            Belief : in Distributions.Distribution;
            Clue   : in Distributions.Distribution
            ) return Distributions.Distribution is
        Prior_Strength : constant Distributions.Weight := Long_Float (Distributions.Variety (Clue));
        Mixed          : constant Distributions.Distribution := Clue + Prior_Strength * Belief;
        begin
        return Distributions.Normalized (Mixed);
        end Updated;
    --# Mixes the previous opinion with the new evidence.
    --# The previous opinion is worth as many "observations" as different letters
    --# were seen in this window: if all sorts of letters followed this context,
    --# I trust it less and trust what I already thought more.

    procedure Train (
            Self         : in out Counting_Oracle;
            Text         : in     Texts.Symbol_Text;
            Letter_Count : in     Symbol;
            Longest      : in     Positive := Default_Longest
            ) is
        Empty_Table : Fragment_Counts.Count_Table;
        begin
        Self.Letter_Count := Letter_Count;
        Self.Longest := Longest;
        Self.Table := Empty_Table;
        Fragment_Counts.Learn (Self.Table, Text, Longest);
        end Train;

    function Fragment_Total (
            Self : in Counting_Oracle
            ) return Natural is
        begin
        return Fragment_Counts.Distinct_Fragments (Self.Table);
        end Fragment_Total;

    overriding function Alphabet_Size (
            Self : in Counting_Oracle
            ) return Symbol is
        begin
        return Self.Letter_Count;
        end Alphabet_Size;

    overriding function Reach (
            Self : in Counting_Oracle
            ) return Natural is
        begin
        return Self.Longest - 1;
        end Reach;

    overriding function Opinion (
            Self     : in Counting_Oracle;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution is
        Left_Known  : constant Natural := Known_Run (Board, Position, To_The_Left, Self.Longest - 1);
        Right_Known : constant Natural := Known_Run (Board, Position, To_The_Right, Self.Longest - 1);
        Left_Used   : Natural := 0;
        Right_Used  : Natural := 0;
        Can_Left    : Boolean;
        Can_Right   : Boolean;
        Belief      : Distributions.Distribution := Distributions.Uniform (Self.Letter_Count);
        --# Before looking at anything, all letters are equally possible.
        begin
        loop
            declare
                Clue : constant Distributions.Distribution :=
                    Evidence (Self, Board, Position, Left_Used, Right_Used);
                begin
                exit when Distributions.Total (Clue) = 0.0;
                --# This window was never seen: a wider one was not either. We stop.
                Belief := Updated (Belief, Clue);
                end;
            exit when Left_Used + 1 + Right_Used >= Self.Longest;
            Can_Left := Left_Used < Left_Known;
            Can_Right := Right_Used < Right_Known;
            exit when not Can_Left and not Can_Right;
            if Should_Widen_Left (Can_Left, Can_Right, Left_Used, Right_Used) then
                Left_Used := Left_Used + 1;
            else
                Right_Used := Right_Used + 1;
                end if;
            end loop;
        return Belief;
        end Opinion;

    end Calipso.Counting_Oracles;
