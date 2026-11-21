--  El lienzo donde se escribe el texto.
--
--  Un lienzo es una fila de celdas, numeradas desde 1.
--  Cada celda está en uno de tres estados:
--
--     Blank   : hueco. Todavía puede ser cualquier letra ("superposición").
--     Given   : letra dada por la persona. Es evidencia fija: no se toca nunca.
--     Guessed : letra decidida por el modelo. Se puede reabrir y volver a decidir.

with Ada.Containers.Vectors;

package Colapso.Canvases is

    type Cell_State is (Blank, Given, Guessed);

    type Canvas is private;
    --# Un lienzo recién declarado está vacío (cero celdas).
    --# Copiar un lienzo es una simple asignación: Copia := Original;

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
    --# Un hueco no tiene letra: preguntar por ella es un error.

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
    --# Colapsar una celda: el hueco pasa a tener una letra decidida.

    procedure Erase (
            Board    : in out Canvas;
            Position : in     Positive
            )
        with
            Pre  => Position <= Length (Board) and then State_At (Board, Position) = Guessed,
            Post => Is_Blank (Board, Position);
    --# Reabrir una letra decidida por el modelo. Las dadas no se pueden borrar.

    procedure Hide (
            Board    : in out Canvas;
            Position : in     Positive
            )
        with
            Pre  => Position <= Length (Board) and then State_At (Board, Position) = Given,
            Post => Is_Blank (Board, Position);
    --# Tapar una letra dada (para el experimento de los puntos ciegos).

    procedure Insert_Blank (
            Board  : in out Canvas;
            Before : in     Positive
            )
        with
            Pre  => Before <= Length (Board) + 1,
            Post => Length (Board) = Length (Board)'Old + 1;
    --# Mete un hueco nuevo justo antes de la posición Before. El lienzo crece.

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

    end Colapso.Canvases;
