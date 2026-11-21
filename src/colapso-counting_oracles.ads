--  Un cerebro que solo sabe contar.
--
--  Idea: para opinar sobre un hueco, miro una "ventana" de letras conocidas
--  a su alrededor y pregunto a la tabla de cuentas:
--
--     "De todas las veces que vi esta ventana en el corpus,
--      ¿qué letra había en el sitio del hueco?"
--
--  Empiezo con una ventana vacía (solo la frecuencia de cada letra) y la voy
--  ensanchando una vecina cada vez, alternando izquierda y derecha. Cada
--  ventana más ancha corrige la opinión de la anterior.

with Colapso.Canvases;
with Colapso.Distributions;
with Colapso.Fragment_Counts;
with Colapso.Oracles;
with Colapso.Texts;

package Colapso.Counting_Oracles is

    Default_Longest : constant Positive := 7;
    --# Ventana más ancha por defecto: el hueco más 6 vecinas.

    type Counting_Oracle is new Oracles.Oracle with private;

    procedure Train (
            Self         : in out Counting_Oracle;
            Text         : in     Texts.Symbol_Text;
            Letter_Count : in     Symbol;
            Longest      : in     Positive := Default_Longest
            );
    --# "Entrenar" este cerebro es solo contar fragmentos.

    function Fragment_Total (
            Self : in Counting_Oracle
            ) return Natural;
    --# Cuántos fragmentos distintos recuerda. Sirve para informar del tamaño.

    overriding function Alphabet_Size (
            Self : in Counting_Oracle
            ) return Symbol;

    overriding function Reach (
            Self : in Counting_Oracle
            ) return Natural;

    overriding function Opinion (
            Self     : in Counting_Oracle;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution;

private

    type Counting_Oracle is new Oracles.Oracle with record
        Letter_Count : Symbol := 1;
        Longest      : Positive := Default_Longest;
        Table        : Fragment_Counts.Count_Table;
        end record;

    end Colapso.Counting_Oracles;
