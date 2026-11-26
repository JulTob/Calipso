with Ada.Numerics.Long_Elementary_Functions;

package body Calipso.Vectors is

    Full_Turn : constant Long_Float := 360.0;

    function "+" (
            Left  : in Vector;
            Right : in Vector
            ) return Vector is
        Other : constant Vector (Left'Range) := Right;
        --# The same numbers as Right, counted from where Left starts.
        Sum   : Vector (Left'Range);
        begin
        for Index in Left'Range loop
            Sum (Index) := Left (Index) + Other (Index);
            end loop;
        return Sum;
        end "+";

    function "-" (
            Left  : in Vector;
            Right : in Vector
            ) return Vector is
        Other      : constant Vector (Left'Range) := Right;
        Difference : Vector (Left'Range);
        begin
        for Index in Left'Range loop
            Difference (Index) := Left (Index) - Other (Index);
            end loop;
        return Difference;
        end "-";

    function "*" (
            Scale : in Long_Float;
            Item  : in Vector
            ) return Vector is
        Scaled : Vector (Item'Range);
        begin
        for Index in Item'Range loop
            Scaled (Index) := Scale * Item (Index);
            end loop;
        return Scaled;
        end "*";

    function "*" (
            Left  : in Vector;
            Right : in Vector
            ) return Long_Float is
        Other : constant Vector (Left'Range) := Right;
        Total : Long_Float := 0.0;
        begin
        for Index in Left'Range loop
            Total := Total + Left (Index) * Other (Index);
            end loop;
        return Total;
        end "*";

    function Length (
            Item : in Vector
            ) return Long_Float is
        Squared : constant Long_Float := Item * Item;
        begin
        return Ada.Numerics.Long_Elementary_Functions.Sqrt (Squared);
        end Length;

    function Unit (
            Item : in Vector
            ) return Vector is
        Size : constant Long_Float := Length (Item);
        begin
        if Size = 0.0 then
            return Item;
            end if;
        return (1.0 / Size) * Item;
        end Unit;

    function Cosine (
            Left  : in Vector;
            Right : in Vector
            ) return Long_Float is
        Lengths : constant Long_Float := Length (Left) * Length (Right);
        Dot     : constant Long_Float := Left * Right;
        begin
        if Lengths = 0.0 then
            return 0.0;
            end if;
        return Long_Float'Max (-1.0, Long_Float'Min (1.0, Dot / Lengths));
        end Cosine;

    function Complex_Product (
            Left  : in Vector;
            Right : in Vector
            ) return Complex is
        Half      : constant Natural := Left'Length / 2;
        Mine      : constant Vector (1 .. 2 * Half) := Left;
        Theirs    : constant Vector (1 .. 2 * Half) := Right;
        Alike     : constant Long_Float := Mine * Theirs;
        One_Way   : constant Long_Float := Mine (1 .. Half) * Theirs (Half + 1 .. 2 * Half);
        Other_Way : constant Long_Float := Mine (Half + 1 .. 2 * Half) * Theirs (1 .. Half);
        begin
        return (Re => Alike, Im => One_Way - Other_Way);
        end Complex_Product;

    function Turn (
            Left  : in Vector;
            Right : in Vector
            ) return Long_Float is
        Product : constant Complex := Complex_Product (Left, Right);
        begin
        if Product.Re = 0.0 and then Product.Im = 0.0 then
            return 0.0;
            end if;
        return Ada.Numerics.Long_Elementary_Functions.Arctan (Y => Product.Im, X => Product.Re, Cycle => Full_Turn);
        end Turn;

    end Calipso.Vectors;
