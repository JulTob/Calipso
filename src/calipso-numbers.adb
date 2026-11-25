package body Calipso.Numbers is

    function Zeros (
            Length : in Natural
            ) return Real_Row is
        begin
        return Real_Vectors.To_Vector (0.0, Ada.Containers.Count_Type (Length));
        end Zeros;

    end Calipso.Numbers;
