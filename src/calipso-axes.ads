--  The main axes of a cloud of vectors.
--
--  Many vectors with hundreds of numbers each mostly differ along a few
--  directions. Those directions are the main axes: arrows of length 1, at right
--  angles to each other. A vector can then be told by a few numbers (how far it
--  goes along each axis) instead of hundreds. That is the compression.
--
--  An axis is found by a patient method that needs only sums and products: take
--  any arrow, stretch it by the cloud, make it of length 1 again, and repeat. It
--  turns until it lies along the direction in which the cloud is widest. For the
--  next axis the same is done, each time removing what lies along the axes found.
--
--  It mirrors reference/calipso_ref/axes.py.

with Calipso.Vectors;

package Calipso.Axes is

    Default_Rounds : constant Positive := 30;

    type Basis is private;

    function Found (
            Rows   : in Vectors.Vector_List;
            Count  : in Natural;
            Rounds : in Positive := Default_Rounds
            ) return Basis;
    --# Count axes of the cloud made by Rows. Every row must be of the same length.

    function Axis_Count (
            Self : in Basis
            ) return Natural;

    function Axis_At (
            Self   : in Basis;
            Number : in Positive
            ) return Vectors.Vector
        with Pre => Number <= Axis_Count (Self);

    function Projected (
            Self : in Basis;
            Item : in Vectors.Vector
            ) return Vectors.Vector
        with Post => Projected'Result'Length = Axis_Count (Self);
    --# The vector told by how far it goes along each axis.

private

    type Basis is record
        Centre : Vectors.Vector_List;
        --# The average vector, alone in its list (a vector of a length not known
        --# beforehand cannot be a plain part of a record). The axes describe how
        --# the others differ from it.
        Axes   : Vectors.Vector_List;
        end record;

    end Calipso.Axes;
