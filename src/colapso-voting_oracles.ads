--  Un cerebro que aprende.
--
--  Idea: cada vecina conocida VOTA. Un voto es una fila de puntos, a favor o
--  en contra de cada letra candidata. Hay una fila de puntos distinta para
--  cada pareja (distancia al hueco, letra que hay ahí):
--
--     "tengo una q justo a tu izquierda"  ->  muchos puntos para la u
--
--  Para opinar se suman los votos de todas las vecinas conocidas (los huecos
--  no votan) y los puntos se convierten en probabilidades.
--
--  Al principio todos los puntos valen 0: el cerebro no sabe nada. Aprende
--  jugando a los puntos ciegos: se le tapa una letra, opina, se le enseña la
--  letra real, y cada vecina que votó corrige un poco sus puntos.

with Ada.Containers.Vectors;

with Colapso.Canvases;
with Colapso.Distributions;
with Colapso.Oracles;
with Colapso.Random_Sources;
with Colapso.Texts;

package Colapso.Voting_Oracles is

    Default_Reach : constant Positive := 12;
    --# Hasta cuántas celdas de distancia vota una vecina, a cada lado.

    type Lesson_Plan is record
        Lessons       : Natural := 4_000;
        --# Cuántos trozos de texto se estudian.
        Piece_Length  : Positive := 64;
        Learning_Rate : Long_Float := 0.5;
        --# Qué parte del error se corrige en cada letra: 0 = nada, 1 = todo de golpe.
        end record;

    Default_Plan : constant Lesson_Plan := (others => <>);

    Not_Prepared : exception;
    --# Se pidió una opinión a un cerebro al que no se le ha hecho Prepare.

    type Voting_Oracle is new Oracles.Oracle with private;

    procedure Prepare (
            Self         : in out Voting_Oracle;
            Letter_Count : in     Symbol;
            Reach        : in     Positive := Default_Reach
            );
    --# Deja el cerebro en blanco: todos los puntos a 0.

    procedure Learn_Cell (
            Self          : in out Voting_Oracle;
            Board         : in     Canvases.Canvas;
            Position      : in     Positive;
            Actual        : in     Symbol;
            Learning_Rate : in     Long_Float;
            Surprise      :    out Long_Float
            )
        with Pre => Position <= Canvases.Length (Board) and then Actual <= Alphabet_Size (Self);
    --# Una lección mínima: opinar sobre una celda tapada, mirar la letra real y corregir.
    --# Surprise es la sorpresa que causó la letra real ANTES de corregir.

    procedure Train (
            Self           : in out Voting_Oracle;
            Text           : in     Texts.Symbol_Text;
            Dice           : in out Random_Sources.Generator;
            Final_Surprise :    out Long_Float;
            Plan           : in     Lesson_Plan := Default_Plan
            )
        with Pre => Natural (Text.Length) > Plan.Piece_Length;
    --# Entrenar = jugar muchas veces a los puntos ciegos.
    --# Final_Surprise es la sorpresa media durante la última décima parte de las lecciones.

    overriding function Alphabet_Size (
            Self : in Voting_Oracle
            ) return Symbol;

    overriding function Reach (
            Self : in Voting_Oracle
            ) return Natural;

    overriding function Opinion (
            Self     : in Voting_Oracle;
            Board    : in Canvases.Canvas;
            Position : in Positive
            ) return Distributions.Distribution;

private

    package Real_Vectors is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Long_Float
            );

    type Voting_Oracle is new Oracles.Oracle with record
        Letter_Count : Symbol := 1;
        Vote_Reach   : Positive := Default_Reach;
        Bias         : Real_Vectors.Vector;
        --# Bias (candidata): puntos de partida de cada letra, sin mirar a nadie.
        Votes        : Real_Vectors.Vector;
        --# Todos los votos en una sola fila larga. Ver Slot_Of en el cuerpo.
        end record;

    end Colapso.Voting_Oracles;
