--  Rows of real numbers, for everything that learns.

with Ada.Containers.Vectors;

package Calipso.Numbers is

    package Real_Vectors is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Long_Float
            );

    subtype Real_Row is Real_Vectors.Vector;
    --# A row of real numbers, numbered from 1. It lives on the heap, so it can be large.

    function Zeros (
            Length : in Natural
            ) return Real_Row;

    end Calipso.Numbers;
