--  Vectors that lie near each other, put into groups.
--
--  Each group has a centre. Every vector joins the group whose centre is
--  nearest; then every centre moves to the middle of its group; and again, until
--  nobody changes group. The groups begin from vectors taken at even steps along
--  the list, so the result is always the same for the same list.
--
--  It mirrors reference/calipso_ref/groups.py.

with Ada.Containers.Vectors;

with Calipso.Vectors;

package Calipso.Groups is

    Default_Passes : constant Positive := 20;

    package Number_Lists is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Natural
            );

    subtype Group_Numbers is Number_Lists.Vector;
    --# The group of each point, counted from 1.

    function Grouped (
            Points : in Calipso.Vectors.Vector_List;
            Count  : in Positive;
            Passes : in Positive := Default_Passes
            ) return Group_Numbers;
    --# Never more groups than points. Every point must be of the same length.

    end Calipso.Groups;
