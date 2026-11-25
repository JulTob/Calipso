--  Calipso: generate text by filling holes, looking at the context on both sides.
--
--  This root package only defines the vocabulary shared by all the others.

package Calipso is

    pragma Pure;

    Max_Symbols : constant := 255;

    type Symbol_Count is range 0 .. Max_Symbols;
    --# For counting symbols: from 0 (none) to 255.

    subtype Symbol is Symbol_Count range 1 .. Max_Symbols;
    --# A symbol is a small number that stands for a letter.
    --# Working with numbers instead of letters lets everything else
    --# (tables, distributions) be plain arrays indexed by symbol.

    Unknown : constant Symbol := 1;
    --# Symbol 1 is reserved for "a letter I do not know".

    end Calipso;
