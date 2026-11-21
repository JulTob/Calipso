with Calipso.Blind_Spots;
with Calipso.Templates;

package body Calipso.Voting_Oracles is

    function Slot_Of (
            Self      : in Voting_Oracle;
            Offset    : in Integer;
            Neighbour : in Symbol;
            Candidate : in Symbol
            ) return Positive is
        Letters : constant Positive := Positive (Self.Letter_Count);
        Side    : constant Natural := Offset + Self.Vote_Reach;
        Row     : constant Natural := Side * Letters + (Natural (Neighbour) - 1);
        begin
        return Row * Letters + (Natural (Candidate) - 1) + 1;
        end Slot_Of;
    --# Place in the long row of the point (distance, neighbour letter, candidate letter).

    procedure Nudge (
            Values : in out Real_Vectors.Vector;
            Slot   : in     Positive;
            Amount : in     Long_Float
            ) is
        Before : constant Long_Float := Values.Element (Slot);
        begin
        Values.Replace_Element (Slot, Before - Amount);
        end Nudge;
    --# Lowers a point by the given amount (or raises it, if the amount is negative).

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
    --# Is there a neighbour with a letter at that distance?

    function Voter_Count (
            Board    : in Canvases.Canvas;
            Position : in Positive;
            Reach    : in Positive
            ) return Natural is
        Count : Natural := 0;
        begin
        for Offset in -Reach .. Reach loop
            if Is_Voter (Board, Position, Offset) then
                Count := Count + 1;
                end if;
            end loop;
        return Count;
        end Voter_Count;

    function Scores_At (
            Self     : in Voting_Oracle;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Score_Array is
        Scores    : Distributions.Score_Array (1 .. Self.Letter_Count);
        Neighbour : Symbol;
        First     : Positive;
        Slot      : Positive;
        begin
        if Self.Bias.Is_Empty then
            raise Not_Prepared with "Prepare must be called before asking for opinions";
            end if;
        for Candidate in Symbol range 1 .. Self.Letter_Count loop
            Scores (Candidate) := Self.Bias.Element (Positive (Candidate));
            end loop;
        for Offset in -Self.Vote_Reach .. Self.Vote_Reach loop
            if Is_Voter (Board, Position, Offset) then
                Neighbour := Canvases.Symbol_At (Board, Position + Offset);
                First := Slot_Of (Self, Offset, Neighbour, 1);
                for Candidate in Symbol range 1 .. Self.Letter_Count loop
                    Slot := First + Positive (Candidate) - 1;
                    Scores (Candidate) := Scores (Candidate) + Self.Votes.Element (Slot);
                    end loop;
                end if;
            end loop;
        return Scores;
        end Scores_At;
    --# Sum of votes for each candidate letter.

    procedure Prepare (
            Self         : in out Voting_Oracle;
            Letter_Count : in     Symbol;
            Reach        : in     Positive := Default_Reach
            ) is
        Letters : constant Positive := Positive (Letter_Count);
        Sides   : constant Positive := 2 * Reach + 1;
        Total   : constant Positive := Sides * Letters * Letters;
        begin
        Self.Letter_Count := Letter_Count;
        Self.Vote_Reach := Reach;
        Self.Bias := Real_Vectors.To_Vector (0.0, Ada.Containers.Count_Type (Letters));
        Self.Votes := Real_Vectors.To_Vector (0.0, Ada.Containers.Count_Type (Total));
        end Prepare;

    procedure Learn_Cell (
            Self          : in out Voting_Oracle;
            Board         : in     Canvases.Canvas;
            Position      : in     Positive;
            Actual        : in     Symbol;
            Learning_Rate : in     Long_Float;
            Surprise      :    out Long_Float
            ) is
        Belief    : constant Distributions.Distribution := Opinion (Self, Board, Position);
        Voters    : constant Natural := Voter_Count (Board, Position, Self.Vote_Reach);
        Step      : constant Long_Float := Learning_Rate / Long_Float (Voters + 1);
        --# The correction is shared equally among the neighbours that voted and the starting points.
        Errors    : Distributions.Score_Array (1 .. Self.Letter_Count);
        Neighbour : Symbol;
        First     : Positive;
        Slot      : Positive;
        begin
        Surprise := Distributions.Surprise_Of (Belief, Actual);
        for Candidate in Symbol range 1 .. Self.Letter_Count loop
            Errors (Candidate) := Distributions.Probability_Of (Belief, Candidate);
            --# Each letter loses what was bet on it...
            end loop;
        Errors (Actual) := Errors (Actual) - 1.0;
        --# ...and the real letter gets what it was missing to reach 1.
        for Candidate in Symbol range 1 .. Self.Letter_Count loop
            Nudge (Self.Bias, Positive (Candidate), Step * Errors (Candidate));
            end loop;
        for Offset in -Self.Vote_Reach .. Self.Vote_Reach loop
            if Is_Voter (Board, Position, Offset) then
                Neighbour := Canvases.Symbol_At (Board, Position + Offset);
                First := Slot_Of (Self, Offset, Neighbour, 1);
                for Candidate in Symbol range 1 .. Self.Letter_Count loop
                    Slot := First + Positive (Candidate) - 1;
                    Nudge (Self.Votes, Slot, Step * Errors (Candidate));
                    end loop;
                end if;
            end loop;
        end Learn_Cell;

    procedure Train (
            Self           : in out Voting_Oracle;
            Text           : in     Texts.Symbol_Text;
            Dice           : in out Random_Sources.Generator;
            Final_Surprise :    out Long_Float;
            Plan           : in     Lesson_Plan := Default_Plan
            ) is
        Room         : constant Positive := Natural (Text.Length) - Plan.Piece_Length;
        Last_Stretch : constant Natural := Plan.Lessons - Plan.Lessons / 10;
        Surprise_Sum : Long_Float := 0.0;
        Cells        : Natural := 0;
        Start        : Natural;
        Rate         : Random_Sources.Unit_Fraction;
        Surprise     : Long_Float;
        Actual       : Symbol;
        begin
        for Lesson in 0 .. Plan.Lessons - 1 loop
            Random_Sources.Draw_Index (Dice, Room, Start);
            declare
                Original : constant Canvases.Canvas := Templates.From_Text (Text, Start + 1, Plan.Piece_Length);
                Board    : Canvases.Canvas := Original;
                begin
                Random_Sources.Draw_Unit (Dice, Rate);
                --# Each lesson hides a different amount: sometimes almost nothing, sometimes almost everything.
                Blind_Spots.Hide_At_Random (Board, Rate, Dice);
                for Position in 1 .. Plan.Piece_Length loop
                    if Canvases.Is_Blank (Board, Position) then
                        Actual := Canvases.Symbol_At (Original, Position);
                        Learn_Cell (Self, Board, Position, Actual, Plan.Learning_Rate, Surprise);
                        if Lesson >= Last_Stretch then
                            Surprise_Sum := Surprise_Sum + Surprise;
                            Cells := Cells + 1;
                            end if;
                        end if;
                    end loop;
                end;
            end loop;
        if Cells = 0 then
            Final_Surprise := 0.0;
        else
            Final_Surprise := Surprise_Sum / Long_Float (Cells);
            end if;
        end Train;

    overriding function Alphabet_Size (
            Self : in Voting_Oracle
            ) return Symbol is
        begin
        return Self.Letter_Count;
        end Alphabet_Size;

    overriding function Reach (
            Self : in Voting_Oracle
            ) return Natural is
        begin
        return Self.Vote_Reach;
        end Reach;

    overriding function Opinion (
            Self     : in Voting_Oracle;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution is
        Scores : constant Distributions.Score_Array := Scores_At (Self, Board, Position);
        begin
        return Distributions.From_Scores (Scores);
        end Opinion;

    end Calipso.Voting_Oracles;
