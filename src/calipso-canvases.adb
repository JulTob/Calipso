package body Calipso.Canvases is

    Blank_Cell : constant Cell := (State => Blank, Value => Unknown);

    function Count_In_State (
            Board  : in Canvas;
            Wanted : in Cell_State
            ) return Natural is
        Result : Natural := 0;
        begin
        for Position in 1 .. Length (Board) loop
            if State_At (Board, Position) = Wanted then
                Result := Result + 1;
                end if;
            end loop;
        return Result;
        end Count_In_State;

    function Length (
            Board : in Canvas
            ) return Natural is
        begin
        return Natural (Board.Cells.Length);
        end Length;

    function State_At (
            Board    : in Canvas;
            Position : in Positive
            ) return Cell_State is
        begin
        return Board.Cells.Element (Position).State;
        end State_At;

    function Is_Blank (
            Board    : in Canvas;
            Position : in Positive
            ) return Boolean is
        begin
        return State_At (Board, Position) = Blank;
        end Is_Blank;

    function Symbol_At (
            Board    : in Canvas;
            Position : in Positive
            ) return Symbol is
        begin
        return Board.Cells.Element (Position).Value;
        end Symbol_At;

    function Blank_Count (
            Board : in Canvas
            ) return Natural is
        begin
        return Count_In_State (Board, Blank);
        end Blank_Count;

    function Guess_Count (
            Board : in Canvas
            ) return Natural is
        begin
        return Count_In_State (Board, Guessed);
        end Guess_Count;

    procedure Append_Given (
            Board : in out Canvas;
            Value : in     Symbol
            ) is
        New_Cell : constant Cell := (State => Given, Value => Value);
        begin
        Board.Cells.Append (New_Cell);
        end Append_Given;

    procedure Append_Blank (
            Board : in out Canvas
            ) is
        begin
        Board.Cells.Append (Blank_Cell);
        end Append_Blank;

    procedure Guess (
            Board    : in out Canvas;
            Position : in     Positive;
            Value    : in     Symbol
            ) is
        New_Cell : constant Cell := (State => Guessed, Value => Value);
        begin
        Board.Cells.Replace_Element (Position, New_Cell);
        end Guess;

    procedure Erase (
            Board    : in out Canvas;
            Position : in     Positive
            ) is
        begin
        Board.Cells.Replace_Element (Position, Blank_Cell);
        end Erase;

    procedure Hide (
            Board    : in out Canvas;
            Position : in     Positive
            ) is
        begin
        Board.Cells.Replace_Element (Position, Blank_Cell);
        end Hide;

    procedure Insert_Blank (
            Board  : in out Canvas;
            Before : in     Positive
            ) is
        begin
        Board.Cells.Insert (Before, Blank_Cell);
        end Insert_Blank;

    end Calipso.Canvases;
