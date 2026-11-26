--  The ways of deciding the kinds of a text.
--
--     By_Shape    a word's kind is what it looks like: capital, size, ending.
--     By_Company  a word's kind is the group of words that keep the same company:
--                   1. every unusual word becomes a vector       (Calipso.Company)
--                   2. the vectors are told by a few numbers     (Calipso.Axes; 0 axes skips this)
--                   3. near vectors are put into groups          (Calipso.Groups)
--                   4. each group becomes a kind of the book     (Calipso.Kinds)
--
--  Either way the result is a Book, so nothing above it has to know which way
--  was used. Each step is a package of its own: another way of making vectors,
--  of shortening them or of grouping them is one more package and one more
--  choice here.
--
--  It mirrors reference/calipso_ref/kind_makers.py.

with Calipso.Axes;
with Calipso.Company;
with Calipso.Groups;
with Calipso.Kinds;
with Calipso.Tokens;

package Calipso.Kind_Makers is

    type Maker is (By_Shape, By_Company);

    Default_Axes   : constant Natural := 24;
    Default_Groups : constant Positive := 80;

    type Settings is record
        Way         : Maker := By_Shape;
        Neighbours  : Calipso.Company.Settings;
        --# What "company" means: how far to look, and what a neighbour counts as.
        Axis_Count  : Natural := Default_Axes;
        --# How many numbers each word is told by. 0 keeps every count.
        Rounds      : Positive := Calipso.Axes.Default_Rounds;
        Group_Count : Positive := Default_Groups;
        Passes      : Positive := Calipso.Groups.Default_Passes;
        end record;

    function Book_Of (
            Sample  : in Tokens.Token_List;
            Options : in Settings
            ) return Kinds.Book;

    end Calipso.Kind_Makers;
