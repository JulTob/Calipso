--  El motor de colapso.
--
--  Bucle (el mismo del algoritmo "Wave Function Collapse"):
--
--     1. Observar : buscar el hueco sobre el que hay MENOS dudas.
--     2. Colapsar : decidir su letra tirando un dado cargado con la opinión.
--     3. Propagar : las opiniones de sus vecinas han cambiado; hay que recalcularlas.
--
--  y repetir hasta que no queden huecos.
--
--  El motor no sabe qué cerebro usa: solo conoce el contrato Oracle.

with Colapso.Canvases;
with Colapso.Oracles;
with Colapso.Random_Sources;

package Colapso.Collapsing is

    type Visiting_Order is (Most_Certain_First, Left_To_Right, At_Random);
    --# Orden de visita de los huecos. El primero es el colapso propiamente dicho;
    --# los otros dos están para poder comparar.

    type Choice_Rule is (By_Chance, Always_Most_Likely);
    --# Cómo se decide la letra: sorteando según la opinión, o cogiendo siempre la más probable.

    procedure Collapse_All (
            Board    : in out Canvases.Canvas;
            Model    : in     Oracles.Oracle'Class;
            Dice     : in out Random_Sources.Generator;
            Order    : in     Visiting_Order := Most_Certain_First;
            Rule     : in     Choice_Rule := By_Chance;
            Observer : access procedure (
                    Current  : in Canvases.Canvas;
                    Position : in Positive
                    ) := null
            )
        with Post => Canvases.Blank_Count (Board) = 0;
    --# Rellena todos los huecos del lienzo.
    --# Observer, si se da, se llama tras cada celda colapsada (para pintar el proceso).

    end Colapso.Collapsing;
