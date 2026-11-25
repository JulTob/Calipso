--  The canvas where the text is written.
--
--  A canvas is a row of cells, numbered from 1.
--  Each cell is in one of three states:
--
--     Blank   : a hole. It can still be any letter ("superposition").
--     Given   : a letter given by the person. It is fixed evidence: never touched.
--     Guessed : a letter decided by the model. It can be reopened and decided again.

with Ada.Containers.Vectors;

package Calipso.Canvases is

    type Cell_State is (Blank, Given, Guessed);

    type Canvas is private;
    --# A newly declared canvas is empty (zero cells).
    --# Copying a canvas is a plain assignment: Copy := Original;

    function Length (
            Board : in Canvas
            ) return Natural;

    function State_At (
            Board    : in Canvas;
            Position : in Positive
            ) return Cell_State
        with Pre => Position <= Length (Board);

    function Is_Blank (
            Board    : in Canvas;
            Position : in Positive
            ) return Boolean
        with Pre => Position <= Length (Board);

    function Symbol_At (
            Board    : in Canvas;
            Position : in Positive
            ) return Symbol
        with Pre => Position <= Length (Board) and then not Is_Blank (Board, Position);
    --# A hole has no letter: asking for it is an error.

    function Blank_Count (
            Board : in Canvas
            ) return Natural;

    function Guess_Count (
            Board : in Canvas
            ) return Natural;

    procedure Append_Given (
            Board : in out Canvas;
            Value : in     Symbol
            );

    procedure Append_Blank (
            Board : in out Canvas
            );

    procedure Guess (
            Board    : in out Canvas;
            Position : in     Positive;
            Value    : in     Symbol
            )
        with
            Pre  => Position <= Length (Board) and then Is_Blank (Board, Position),
            Post => State_At (Board, Position) = Guessed;
    --# Collapse a cell: the hole now has a decided letter.

    procedure Erase (
            Board    : in out Canvas;
            Position : in     Positive
            )
        with
            Pre  => Position <= Length (Board) and then State_At (Board, Position) = Guessed,
            Post => Is_Blank (Board, Position);
    --# Reopen a letter decided by the model. Given letters cannot be erased.

    procedure Hide (
            Board    : in out Canvas;
            Position : in     Positive
            )
        with
            Pre  => Position <= Length (Board) and then State_At (Board, Position) = Given,
            Post => Is_Blank (Board, Position);
    --# Hide a given letter (for the blind-spot experiment).

    procedure Insert_Blank (
            Board  : in out Canvas;
            Before : in     Positive
            )
        with
            Pre  => Before <= Length (Board) + 1,
            Post => Length (Board) = Length (Board)'Old + 1;
    --# Puts a new hole just before position Before. The canvas grows.

private

    type Cell is record
        State : Cell_State := Blank;
        Value : Symbol := Unknown;
        end record;

    package Cell_Vectors is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Cell
            );

    type Canvas is record
        Cells : Cell_Vectors.Vector;
        end record;

    end Calipso.Canvases;
