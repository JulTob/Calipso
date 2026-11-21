package body Calipso.Fetchers is

    function Same (
            Left  : in Fetcher'Class;
            Right : in Fetcher'Class
            ) return Boolean is
        begin
        return Left = Right;
        end Same;

    end Calipso.Fetchers;
