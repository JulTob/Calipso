--  El álgebra de las opiniones.
--
--  Una distribución reparte "peso" entre las letras del alfabeto.
--  Si los pesos suman 1 es una probabilidad; si no, son cuentas sin normalizar.
--
--  Operaciones del álgebra:
--     A + B           juntar dos montones de evidencia
--     Factor * A      darle más o menos fuerza a una opinión
--     Normalized (A)  convertir cuentas en probabilidades
--     From_Scores (P) convertir puntos en probabilidades

package Colapso.Distributions is

    subtype Weight is Long_Float range 0.0 .. Long_Float'Last;
    --# Un peso nunca es negativo. El propio tipo lo vigila.

    Smallest_Probability : constant := 1.0E-300;
    --# Suelo para no pedir nunca el logaritmo de cero.

    type Distribution (Size : Symbol) is private;
    --# Size es el número de letras del alfabeto sobre el que se opina.

    type Score_Array is array (Symbol range <>) of Long_Float;
    --# Puntos por letra: cualquier número, positivo o negativo. Más puntos = más probable.

    function Zero (
            Size : in Symbol
            ) return Distribution
        with Post => Zero'Result.Size = Size;

    function From_Scores (
            Scores : in Score_Array
            ) return Distribution
        with
            Pre  => Scores'First = 1 and then Scores'Length >= 1,
            Post => From_Scores'Result.Size = Scores'Last;
    --# Convierte puntos en probabilidades (se llama "softmax").

    function Uniform (
            Size : in Symbol
            ) return Distribution
        with Post => Uniform'Result.Size = Size;
    --# Todas las letras igual de posibles: la opinión de quien no sabe nada.

    function Weight_Of (
            Item  : in Distribution;
            Value : in Symbol
            ) return Weight
        with Pre => Value <= Item.Size;

    procedure Set_Weight (
            Item   : in out Distribution;
            Value  : in     Symbol;
            Amount : in     Weight
            )
        with Pre => Value <= Item.Size;

    function Total (
            Item : in Distribution
            ) return Weight;

    function Variety (
            Item : in Distribution
            ) return Natural;
    --# Cuántas letras distintas tienen algo de peso.

    function "+" (
            Left  : in Distribution;
            Right : in Distribution
            ) return Distribution
        with Pre => Left.Size = Right.Size;

    function "*" (
            Factor : in Weight;
            Right  : in Distribution
            ) return Distribution;

    function Normalized (
            Item : in Distribution
            ) return Distribution
        with
            Pre  => Total (Item) > 0.0,
            Post => Normalized'Result.Size = Item.Size;

    function Probability_Of (
            Item  : in Distribution;
            Value : in Symbol
            ) return Long_Float
        with Pre => Value <= Item.Size and then Total (Item) > 0.0;

    function Entropy (
            Item : in Distribution
            ) return Long_Float
        with Pre => Total (Item) > 0.0;
    --# Incertidumbre, en nats. 0 = seguro del todo. Cuanto mayor, más dudas.

    function Surprise_Of (
            Item  : in Distribution;
            Value : in Symbol
            ) return Long_Float
        with Pre => Value <= Item.Size and then Total (Item) > 0.0;
    --# Cuánto sorprende ver esta letra, en nats. 0 = era justo lo esperado.

    function Most_Likely (
            Item : in Distribution
            ) return Symbol
        with Post => Most_Likely'Result <= Item.Size;

    function Sampled (
            Item : in Distribution;
            Unit : in Long_Float
            ) return Symbol
        with
            Pre  => Total (Item) > 0.0 and then Unit >= 0.0 and then Unit < 1.0,
            Post => Sampled'Result <= Item.Size;
    --# Tira un dado cargado. Unit es un número al azar en [0, 1).

private

    type Weight_Array is array (Symbol range <>) of Weight;

    type Distribution (Size : Symbol) is record
        Weights : Weight_Array (1 .. Size) := (others => 0.0);
        end record;

    end Colapso.Distributions;
