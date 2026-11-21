--  El experimento de los puntos ciegos.
--
--  Se coge texto real, se tapan letras al azar y se pide al modelo que las
--  rellene. Como conocemos la respuesta, podemos contar aciertos.
--
--  Con el cerebro de conteo esto es un EXAMEN. Con una red neuronal, este
--  mismo juego será el ENTRENAMIENTO: tapar, apostar, destapar y corregir.

with Colapso.Canvases;
with Colapso.Oracles;
with Colapso.Random_Sources;
with Colapso.Texts;

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

    type Exam_Result is record
        Hidden       : Natural := 0;
        Hits         : Natural := 0;
        Surprise_Sum : Long_Float := 0.0;
        end record;

    function Mean_Surprise (
            Result : in Exam_Result
            ) return Long_Float;

    procedure Examine (
            Model        : in     Oracles.Oracle'Class;
            Text         : in     Texts.Symbol_Text;
            Dice         : in out Random_Sources.Generator;
            Pieces       : in     Natural;
            Piece_Length : in     Positive;
            Rate         : in     Random_Sources.Unit_Fraction;
            Result       :    out Exam_Result
            )
        with Pre => Natural (Text.Length) > Piece_Length;
    --# El mismo examen para cualquier cerebro: tapar letras al azar en trozos de
    --# texto y preguntar por cada letra tapada, SIN rellenar las demás.
    --# Mide dos cosas: cuántas acierta y cuánto le sorprende la letra real.

    end Colapso.Blind_Spots;
