--  El contrato de cualquier "cerebro".
--
--  Un oráculo responde a una sola pregunta:
--
--     "Mirando lo que hay alrededor, ¿qué letra crees que va en esta celda?"
--
--  y contesta con una distribución (una opinión con dudas, no una letra).
--
--  El motor de colapso solo conoce este contrato. Hoy el cerebro es una
--  tabla de cuentas; mañana será una red neuronal. El motor no cambiará.

with Colapso.Canvases;
with Colapso.Distributions;

package Colapso.Oracles is

    type Oracle is interface;

    function Alphabet_Size (
            Self : in Oracle
            ) return Symbol is abstract;

    function Reach (
            Self : in Oracle
            ) return Natural is abstract;
    --# A cuántas celdas de distancia puede influir una letra en la opinión sobre otra.
    --# El motor lo usa para saber qué opiniones caducan cuando una celda colapsa.

    function Opinion (
            Self     : in Oracle;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution is abstract
        with
            Pre'Class  => Position <= Canvases.Length (Board),
            Post'Class => Opinion'Result.Size = Alphabet_Size (Self);
    --# Opinión sobre la celda Position mirando SOLO a sus vecinas, nunca a ella misma.
    --# Por eso sirve igual para rellenar un hueco que para examinar una letra ya puesta.

    end Colapso.Oracles;
