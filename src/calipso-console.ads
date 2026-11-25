--  Border with the terminal.
--
--  Inside the program text is Wide_Wide_String (one letter = one element).
--  Outside (terminal, arguments, error messages) it is UTF-8 bytes inside
--  a String. The conversions happen here and only here.

package Calipso.Console is

    function To_UTF_8 (
            Text : in Wide_Wide_String
            ) return String;

    function From_UTF_8 (
            Bytes : in String
            ) return Wide_Wide_String;
    --# If the bytes are not valid UTF-8, it returns an empty text.

    function Visible (
            Text : in Wide_Wide_String
            ) return Wide_Wide_String;
    --# Replaces each line feed with the two characters \n,
    --# so that a canvas always fits on a single screen line.

    function Image (
            Value : in Integer
            ) return String;
    --# The number with no leading spaces.

    function Image (
            Value    : in Long_Float;
            Decimals : in Natural := 3
            ) return String;
    --# The number in fixed-point notation, with no leading spaces.

    procedure Put_Line (
            Text : in String
            );

    procedure Put_Wide_Line (
            Text : in Wide_Wide_String
            );
    --# For internal text (for example, a drawn canvas): converts it to UTF-8 and writes it.

    end Calipso.Console;
