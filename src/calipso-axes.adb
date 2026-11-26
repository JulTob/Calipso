package body Calipso.Axes is

    use type Vectors.Vector;

    Start_Step  : constant := 7;
    Start_Shift : constant := 3;
    Start_Cycle : constant := 11;

    function Centre_Of (
            Rows : in Vectors.Vector_List
            ) return Vectors.Vector is
        Total : Vectors.Vector (1 .. Rows.First_Element'Length) := (others => 0.0);
        begin
        for Row of Rows loop
            Total := Total + Row;
            end loop;
        return (1.0 / Long_Float (Natural (Rows.Length))) * Total;
        end Centre_Of;

    function Start_Arrow (
            Width  : in Natural;
            Number : in Positive
            ) return Vectors.Vector is
        Arrow : Vectors.Vector (1 .. Width);
        begin
        for Place in Arrow'Range loop
            Arrow (Place) := Long_Float ((Place * Start_Step + Number * Start_Shift) mod Start_Cycle + 1);
            end loop;
        return Arrow;
        end Start_Arrow;
    --# Any arrow will do to begin with, as long as it is always the same one.

    function Without (
            Arrow   : in Vectors.Vector;
            Earlier : in Vectors.Vector_List
            ) return Vectors.Vector is
        Rest  : Vectors.Vector := Arrow;
        Along : Long_Float;
        begin
        for Axis of Earlier loop
            Along := Rest * Axis;
            Rest := Rest - Along * Axis;
            end loop;
        return Rest;
        end Without;
    --# The arrow with what lies along the axes already found taken away.

    function Stretched (
            Rows   : in Vectors.Vector_List;
            Centre : in Vectors.Vector;
            Arrow  : in Vectors.Vector
            ) return Vectors.Vector is
        Offset   : constant Long_Float := Centre * Arrow;
        Total    : Vectors.Vector (Arrow'Range) := (others => 0.0);
        Pull_Sum : Long_Float := 0.0;
        Pull     : Long_Float;
        begin
        for Row of Rows loop
            Pull := Row * Arrow;
            Pull := Pull - Offset;
            Total := Total + Pull * Row;
            Pull_Sum := Pull_Sum + Pull;
            end loop;
        return Total - Pull_Sum * Centre;
        end Stretched;
    --# Every vector pulls the arrow toward itself, as hard as the two agree.

    function One_Axis (
            Rows    : in Vectors.Vector_List;
            Centre  : in Vectors.Vector;
            Earlier : in Vectors.Vector_List;
            Number  : in Positive;
            Rounds  : in Positive
            ) return Vectors.Vector is
        Arrow : Vectors.Vector := Vectors.Unit (Without (Start_Arrow (Centre'Length, Number), Earlier));
        begin
        for Round in 1 .. Rounds loop
            Arrow := Vectors.Unit (Without (Stretched (Rows, Centre, Arrow), Earlier));
            end loop;
        return Arrow;
        end One_Axis;

    function Found (
            Rows   : in Vectors.Vector_List;
            Count  : in Natural;
            Rounds : in Positive := Default_Rounds
            ) return Basis is
        Self : Basis;
        begin
        if Rows.Is_Empty then
            return Self;
            end if;
        Self.Centre.Append (Centre_Of (Rows));
        for Number in 1 .. Count loop
            Self.Axes.Append (One_Axis (Rows, Self.Centre.First_Element, Self.Axes, Number, Rounds));
            end loop;
        return Self;
        end Found;

    function Axis_Count (
            Self : in Basis
            ) return Natural is
        begin
        return Natural (Self.Axes.Length);
        end Axis_Count;

    function Axis_At (
            Self   : in Basis;
            Number : in Positive
            ) return Vectors.Vector is
        begin
        return Self.Axes.Element (Number);
        end Axis_At;

    function Projected (
            Self : in Basis;
            Item : in Vectors.Vector
            ) return Vectors.Vector is
        Short : Vectors.Vector (1 .. Axis_Count (Self));
        begin
        if Self.Centre.Is_Empty then
            return Short;
            end if;
        declare
            Moved : constant Vectors.Vector := Item - Self.Centre.First_Element;
            begin
            for Number in Short'Range loop
                Short (Number) := Moved * Self.Axes.Element (Number);
                end loop;
            end;
        return Short;
        end Projected;

    end Calipso.Axes;
