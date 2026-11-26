package body Calipso.Groups is

    use type Calipso.Vectors.Vector;

    subtype Vector is Calipso.Vectors.Vector;
    subtype Vector_List is Calipso.Vectors.Vector_List;

    function Distance_Squared (
            Left  : in Vector;
            Right : in Vector
            ) return Long_Float is
        Apart : constant Vector := Left - Right;
        begin
        return Apart * Apart;
        end Distance_Squared;

    function Start_Centres (
            Points : in Vector_List;
            Count  : in Positive
            ) return Vector_List is
        Size    : constant Natural := Natural (Points.Length);
        Centres : Vector_List;
        begin
        for Group in 1 .. Count loop
            Centres.Append (Points.Element (1 + ((Group - 1) * Size) / Count));
            end loop;
        return Centres;
        end Start_Centres;
    --# Points taken at even steps along the list.

    function Nearest (
            Point   : in Vector;
            Centres : in Vector_List
            ) return Positive is
        Best     : Positive := 1;
        Least    : Long_Float := Distance_Squared (Point, Centres.First_Element);
        Distance : Long_Float;
        begin
        for Group in 2 .. Natural (Centres.Length) loop
            Distance := Distance_Squared (Point, Centres.Element (Group));
            if Distance < Least then
                Best := Group;
                Least := Distance;
                end if;
            end loop;
        return Best;
        end Nearest;
    --# The number of the nearest centre. On a tie, the first.

    function Middle_Of (
            Points     : in Vector_List;
            Numbers    : in Group_Numbers;
            Group      : in Positive;
            Old_Centre : in Vector
            ) return Vector is
        Total   : Vector (Old_Centre'Range) := (others => 0.0);
        Members : Natural := 0;
        begin
        for Place in 1 .. Natural (Points.Length) loop
            if Numbers.Element (Place) = Group then
                Total := Total + Points.Element (Place);
                Members := Members + 1;
                end if;
            end loop;
        if Members = 0 then
            return Old_Centre;
            end if;
        return (1.0 / Long_Float (Members)) * Total;
        end Middle_Of;
    --# The middle of the members of one group. A group with no members keeps its centre.

    procedure Join_Nearest (
            Points  : in     Vector_List;
            Centres : in     Vector_List;
            Numbers : in out Group_Numbers;
            Changed :    out Boolean
            ) is
        Group : Positive;
        begin
        Changed := False;
        for Place in 1 .. Natural (Points.Length) loop
            Group := Nearest (Points.Element (Place), Centres);
            if Group /= Numbers.Element (Place) then
                Numbers.Replace_Element (Place, Group);
                Changed := True;
                end if;
            end loop;
        end Join_Nearest;
    --# Every point joins the group whose centre is nearest.

    function Grouped (
            Points : in Calipso.Vectors.Vector_List;
            Count  : in Positive;
            Passes : in Positive := Default_Passes
            ) return Group_Numbers is
        Size    : constant Natural := Natural (Points.Length);
        Kept    : constant Natural := Natural'Min (Count, Size);
        Numbers : Group_Numbers;
        Centres : Vector_List;
        Changed : Boolean;
        begin
        if Size = 0 then
            return Numbers;
            end if;
        Centres := Start_Centres (Points, Kept);
        Numbers.Append (0, Ada.Containers.Count_Type (Size));
        for Pass in 1 .. Passes loop
            Join_Nearest (Points, Centres, Numbers, Changed);
            exit when not Changed;
            for Group in 1 .. Kept loop
                Centres.Replace_Element (Group, Middle_Of (Points, Numbers, Group, Centres.Element (Group)));
                end loop;
            end loop;
        return Numbers;
        end Grouped;

    end Calipso.Groups;
