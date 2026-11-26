with Calipso.Vectors;

package body Calipso.Kind_Makers is

    use type Tokens.Token_Sort;

    function Points_Of (
            Table   : in Company.Table;
            Options : in Settings
            ) return Vectors.Vector_List is
        Rows   : constant Vectors.Vector_List := Company.Rows_Of (Table);
        Points : Vectors.Vector_List;
        begin
        if Options.Axis_Count = 0 then
            return Rows;
            end if;
        declare
            Basis : constant Axes.Basis := Axes.Found (Rows, Options.Axis_Count, Options.Rounds);
            begin
            for Row of Rows loop
                Points.Append (Vectors.Unit (Axes.Projected (Basis, Row)));
                end loop;
            end;
        return Points;
        end Points_Of;
    --# What is grouped: the vectors themselves, or their short form along the main axes.

    function Groups_By_Word (
            Sample  : in Tokens.Token_List;
            Table   : in Company.Table;
            Numbers : in Groups.Group_Numbers
            ) return Kinds.Word_Groups.Map is
        Chosen : Kinds.Word_Groups.Map;
        begin
        for Token of Sample loop
            if Tokens.Sort_Of (Token) = Tokens.Word and then not Chosen.Contains (Token)
               and then Company.Has_Word (Table, Token)
            then
                Chosen.Insert (Token, Numbers.Element (Company.Row_Of (Table, Token)));
                end if;
            end loop;
        return Chosen;
        end Groups_By_Word;
    --# The group of every word of the text that has a row in the table.

    function Book_By_Company (
            Sample   : in Tokens.Token_List;
            By_Looks : in Kinds.Book;
            Options  : in Settings
            ) return Kinds.Book is
        Table : constant Company.Table := Company.Built (Sample, By_Looks, Options.Neighbours);
        begin
        if Company.Row_Count (Table) = 0 then
            return By_Looks;
            --# No unusual word to group: the book by shape is all there is.
            end if;
        declare
            Points  : constant Vectors.Vector_List := Points_Of (Table, Options);
            Numbers : constant Groups.Group_Numbers := Groups.Grouped (Points, Options.Group_Count, Options.Passes);
            Chosen  : constant Kinds.Word_Groups.Map := Groups_By_Word (Sample, Table, Numbers);
            begin
            return Kinds.Built_By_Groups (Sample, Chosen, Options.Group_Count);
            end;
        end Book_By_Company;

    function Book_Of (
            Sample  : in Tokens.Token_List;
            Options : in Settings
            ) return Kinds.Book is
        By_Looks : constant Kinds.Book := Kinds.Built (Sample);
        begin
        if Options.Way = By_Shape then
            return By_Looks;
            end if;
        return Book_By_Company (Sample, By_Looks, Options);
        end Book_Of;

    end Calipso.Kind_Makers;
