--  Azar repetible.
--
--  Un generador propio y muy simple. Con la misma semilla saca siempre
--  los mismos números, aquí y en la referencia en Python. Así cualquier
--  resultado se puede repetir y comprobar.

with Interfaces;

package Colapso.Random_Sources is

    subtype Unit_Fraction is Long_Float range 0.0 .. 1.0;

    type Generator is private;

    function Seeded (
            Seed : in Natural
            ) return Generator;

    procedure Draw_Unit (
            Source : in out Generator;
            Unit   :    out Unit_Fraction
            )
        with Post => Unit < 1.0;
    --# Saca un número en [0, 1) y avanza el generador.
    --# Es un procedimiento y no una función porque cambia el generador:
    --# así el efecto queda a la vista en cada llamada.

    procedure Draw_Index (
            Source : in out Generator;
            Below  : in     Positive;
            Index  :    out Natural
            )
        with Post => Index < Below;
    --# Saca un entero en 0 .. Below - 1.

private

    type Generator is record
        State : Interfaces.Unsigned_64 := 0;
        end record;

    end Colapso.Random_Sources;
