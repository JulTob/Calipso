with Ada.Long_Float_Text_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;

package body Calipso.Console is

    Line_Feed : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);

    function To_UTF_8 (
            Text : in Wide_Wide_String
            ) return String is
        begin
        return Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Text);
        end To_UTF_8;

    function From_UTF_8 (
            Bytes : in String
            ) return Wide_Wide_String is
        begin
        return Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode (Bytes);
        exception
        when Ada.Strings.UTF_Encoding.Encoding_Error =>
            return "";
        end From_UTF_8;

    function Visible (
            Text : in Wide_Wide_String
            ) return Wide_Wide_String is
        use Ada.Strings.Wide_Wide_Unbounded;
        Result : Unbounded_Wide_Wide_String;
        begin
        for Char of Text loop
            if Char = Line_Feed then
                Append (Result, "\n");
            else
                Append (Result, Char);
                end if;
            end loop;
        return To_Wide_Wide_String (Result);
        end Visible;

    function Image (
            Value : in Integer
            ) return String is
        Raw : constant String := Integer'Image (Value);
        begin
        return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
        end Image;

    function Image (
            Value    : in Long_Float;
            Decimals : in Natural := 3
            ) return String is
        Buffer : String (1 .. 40);
        begin
        Ada.Long_Float_Text_IO.Put (
            To   => Buffer,
            Item => Value,
            Aft  => Decimals,
            Exp  => 0
            );
        return Ada.Strings.Fixed.Trim (Buffer, Ada.Strings.Both);
        end Image;

    procedure Put_Line (
            Text : in String
            ) is
        begin
        Ada.Text_IO.Put_Line (Text);
        end Put_Line;

    procedure Put_Wide_Line (
            Text : in Wide_Wide_String
            ) is
        begin
        Ada.Text_IO.Put_Line (To_UTF_8 (Text));
        end Put_Wide_Line;

    end Calipso.Console;
