--  Write and read saved brains as plain text.
--
--  A saved brain is a text file with ONE item per line: a word, a whole number
--  or a real number. Dull on purpose: any editor can open it, and Ada and
--  Python read each other's files.
--
--  Real numbers are written with 17 significant digits, which is enough to get
--  back exactly the same number. A long row of numbers is saved "sparse": only
--  the entries that are not zero, each with its position.

with Ada.Text_IO;

with Calipso.Numbers;

package Calipso.Records is

    Record_Error : exception;
    --# The file is missing, ends too soon, or does not hold what was expected.

    procedure Write_Word (
            File : in Ada.Text_IO.File_Type;
            Word : in String
            );

    procedure Write_Count (
            File  : in Ada.Text_IO.File_Type;
            Count : in Natural
            );

    procedure Write_Real (
            File  : in Ada.Text_IO.File_Type;
            Value : in Long_Float
            );

    procedure Write_Reals (
            File   : in Ada.Text_IO.File_Type;
            Values : in Numbers.Real_Row
            );

    function Read_Word (
            File : in Ada.Text_IO.File_Type
            ) return String;
    --# The reading operations are functions for convenience, although each one
    --# moves the file forward: a file is outside state by nature.

    function Read_Count (
            File : in Ada.Text_IO.File_Type
            ) return Natural;

    function Read_Real (
            File : in Ada.Text_IO.File_Type
            ) return Long_Float;

    function Read_Reals (
            File : in Ada.Text_IO.File_Type
            ) return Numbers.Real_Row;

    procedure Expect_Word (
            File   : in Ada.Text_IO.File_Type;
            Wanted : in String
            );

    end Calipso.Records;
