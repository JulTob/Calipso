--  El experimento de los puntos ciegos.
--
--  Se coge texto real, se tapan letras al azar y se pide al modelo que las
--  rellene. Como conocemos la respuesta, podemos contar aciertos.
--
--  Con el cerebro de conteo esto es un EXAMEN. Con una red neuronal, este
--  mismo juego será el ENTRENAMIENTO: tapar, apostar, destapar y corregir.

with Colapso.Canvases;
with Colapso.Random_Sources;

package Colapso.Blind_Spots is

    type Score is record
        Hidden    : Natural := 0;
        Recovered : Natural := 0;
        end record;

    procedure Hide_At_Random (
            Board : in out Canvases.Canvas;
            Rate  : in     Random_Sources.Unit_Fraction;
            Dice  : in out Random_Sources.Generator
            );
    --# Cada letra dada se tapa con probabilidad Rate.

    function Scored (
            Filled   : in Canvases.Canvas;
            Original : in Canvases.Canvas
            ) return Score
        with Pre => Canvases.Length (Filled) = Canvases.Length (Original);
    --# Compara el lienzo rellenado con el original, celda a celda.

    end Colapso.Blind_Spots;
