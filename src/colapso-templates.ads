--  Escribir y leer lienzos como texto.
--
--  Notación de una plantilla:
--
--     _        un hueco de una celda
--     [25]     un hueco de 25 celdas
--     [...]    un hueco del tamaño por defecto
--     \n       un salto de línea (frontera de párrafo)
--     lo demás son letras dadas, tal cual

with Colapso.Alphabets;
with Colapso.Canvases;
with Colapso.Texts;

package Colapso.Templates is

    Blank_Mark   : constant Wide_Wide_Character := '_';
    Hole_Opening : constant Wide_Wide_Character := '[';
    Hole_Closing : constant Wide_Wide_Character := ']';

    Default_Hole : constant Positive := 30;
    Largest_Hole : constant Positive := 10_000;

    function Parsed (
            Template : in Wide_Wide_String;
            Letters  : in Alphabets.Alphabet
            ) return Canvases.Canvas;

    function From_Text (
            Text   : in Texts.Symbol_Text;
            First  : in Positive;
            Length : in Natural
            ) return Canvases.Canvas
        with Pre => First + Length - 1 <= Text.Last_Index;
    --# Un lienzo con un trozo de texto real, todo como letras dadas.

    function Rendered (
            Board        : in Canvases.Canvas;
            Letters      : in Alphabets.Alphabet;
            Mark_Guesses : in Boolean := False
            ) return Wide_Wide_String;
    --# Con Mark_Guesses, lo que escribió el modelo sale entre corchetes.

    end Colapso.Templates;
