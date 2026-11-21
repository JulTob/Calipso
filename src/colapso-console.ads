--  Frontera con la terminal.
--
--  Dentro del programa el texto es Wide_Wide_String (una letra = un elemento).
--  Fuera (terminal, argumentos, mensajes de error) son bytes en UTF-8 dentro
--  de un String. Las conversiones se hacen aquí y solo aquí.

package Colapso.Console is

    function To_UTF_8 (
            Text : in Wide_Wide_String
            ) return String;

    function From_UTF_8 (
            Bytes : in String
            ) return Wide_Wide_String;
    --# Si los bytes no son UTF-8 válido, devuelve un texto vacío.

    function Visible (
            Text : in Wide_Wide_String
            ) return Wide_Wide_String;
    --# Cambia cada salto de línea por los dos caracteres \n,
    --# para que un lienzo quepa siempre en una sola línea de pantalla.

    function Image (
            Value : in Integer
            ) return String;
    --# El número sin espacios delante.

    function Image (
            Value    : in Long_Float;
            Decimals : in Natural := 3
            ) return String;
    --# El número con coma fija, sin espacios delante.

    procedure Put_Line (
            Text : in String
            );

    procedure Put_Wide_Line (
            Text : in Wide_Wide_String
            );
    --# Para texto interno (por ejemplo, un lienzo pintado): lo pasa a UTF-8 y lo escribe.

    end Colapso.Console;
