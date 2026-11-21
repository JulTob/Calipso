--  Encontrar lo que chirría y arreglarlo.
--
--  Después de colapsar, cada letra se puede examinar: "si te tapo, ¿tus vecinas
--  te habrían adivinado?". Si la respuesta es "ni de lejos", esa letra sorprende:
--  ahí el texto no encaja.
--
--     Sorpresa : cuánto extraña una letra a sus vecinas (en nats).
--     Tensión  : suma de la sorpresa que pasa de lo tolerable, en la zona
--                que el modelo ha tocado. Tensión 0 = "todo encaja".
--
--  Relajar el lienzo = repetir: buscar la letra que más sorprende, reabrir su
--  entorno y volver a colapsar. Si con el mismo sitio no mejora, se prueba a
--  ENSANCHAR: meter celdas nuevas ahí. Así el texto crece solo donde hace falta.

with Colapso.Canvases;
with Colapso.Oracles;
with Colapso.Random_Sources;

package Colapso.Repairing is

    type Settings is record
        Tolerance   : Long_Float := 4.0;
        --# Sorpresa tolerable por letra, en nats. 4 nats = "pasa 1 de cada 55 veces".
        Max_Rounds  : Natural := 40;
        Radius      : Natural := 4;
        --# Al reabrir, cuántas celdas a cada lado del foco se vuelven huecos.
        Extra_Cells : Positive := 3;
        --# Al ensanchar, cuántas celdas nuevas se meten.
        Max_Length  : Positive := 2_000;
        Can_Grow    : Boolean := True;
        end record;

    Default_Settings : constant Settings := (others => <>);

    type Report is record
        Rounds        : Natural := 0;
        Reopenings    : Natural := 0;
        Widenings     : Natural := 0;
        Final_Tension : Long_Float := 0.0;
        end record;

    function Surprise_At (
            Board    : in Canvases.Canvas;
            Model    : in Oracles.Oracle'Class;
            Position : in Positive
            ) return Long_Float
        with Pre => Position <= Canvases.Length (Board) and then not Canvases.Is_Blank (Board, Position);

    function Tension (
            Board     : in Canvases.Canvas;
            Model     : in Oracles.Oracle'Class;
            Tolerance : in Long_Float
            ) return Long_Float
        with Post => Tension'Result >= 0.0;

    function Most_Surprising_Cell (
            Board : in Canvases.Canvas;
            Model : in Oracles.Oracle'Class
            ) return Natural;
    --# La celda medida que más sorprende. 0 si no hay ninguna que medir.

    procedure Relax (
            Board   : in out Canvases.Canvas;
            Model   : in     Oracles.Oracle'Class;
            Dice    : in out Random_Sources.Generator;
            Outcome :    out Report;
            Options : in     Settings := Default_Settings
            );
    --# Las letras dadas no cambian nunca. La tensión final nunca es mayor que la inicial.

    end Colapso.Repairing;
