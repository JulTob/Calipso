with Ada.Strings;
with Ada.Strings.Fixed;

package body Calipso.Neurons is

    function Is_Voter (
            Board    : in Canvases.Canvas;
            Position : in Positive;
            Offset   : in Integer
            ) return Boolean is
        Neighbour : constant Integer := Position + Offset;
        begin
        if Offset = 0 then
            return False;
            end if;
        if Neighbour < 1 then
            return False;
            end if;
        if Neighbour > Canvases.Length (Board) then
            return False;
            end if;
        return not Canvases.Is_Blank (Board, Neighbour);
        end Is_Voter;

    function Image (
            Value : in Natural
            ) return String is
        begin
        return Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left);
        end Image;

    function With_Sizes (
            Word         : in String;
            First        : in Natural;
            Usual_First  : in Natural;
            Second       : in Natural;
            Usual_Second : in Natural
            ) return String is
        begin
        if Second /= Usual_Second then
            return Word & ":" & Image (First) & ":" & Image (Second);
            end if;
        if First /= Usual_First then
            return Word & ":" & Image (First);
            end if;
        return Word;
        end With_Sizes;

    function Same (
            Left  : in Neuron'Class;
            Right : in Neuron'Class
            ) return Boolean is
        begin
        return Left = Right;
        end Same;

    end Calipso.Neurons;
