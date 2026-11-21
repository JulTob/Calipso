--  Pasar de un archivo de texto a una fila de símbolos.
--
--  Frontera con el mundo exterior: fuera, el texto son bytes en UTF-8;
--  dentro, son símbolos. Aquí es el único sitio donde se abre un archivo.

with Ada.Containers.Vectors;

with Colapso.Alphabets;

package Colapso.Texts is

    package Symbol_Vectors is new Ada.Containers.Vectors (
            Index_Type   => Positive,
            Element_Type => Symbol
            );

    subtype Symbol_Text is Symbol_Vectors.Vector;
    --# Un texto ya traducido: una fila de símbolos, numerada desde 1.

    Reading_Error : exception;
    --# El archivo no existe, no se puede abrir o no es UTF-8 válido.

    procedure For_Each_Character (
            File_Name : in String;
            Visit     : not null access procedure (Char : in Wide_Wide_Character)
            );
    --# Recorre el archivo letra a letra y llama a Visit con cada una.
    --# Cada línea termina en un salto de línea, también la última.

    procedure Learn_Alphabet (
            File_Name : in     String;
            Letters   : in out Alphabets.Alphabet
            );
    --# Primera pasada: apuntar cada letra nueva, por orden de aparición.

    function Read_Symbols (
            File_Name : in String;
            Letters   : in Alphabets.Alphabet
            ) return Symbol_Text;
    --# Segunda pasada: traducir cada letra a su símbolo.

    function Part (
            Text  : in Symbol_Text;
            First : in Positive;
            Last  : in Natural
            ) return Symbol_Text
        with Pre => Last <= Text.Last_Index;
    --# El trozo del texto que va de First a Last, como texto nuevo.

    function Encoded (
            Plain   : in Wide_Wide_String;
            Letters : in Alphabets.Alphabet
            ) return Symbol_Text;

    function Decoded (
            Text    : in Symbol_Text;
            Letters : in Alphabets.Alphabet
            ) return Wide_Wide_String;

    end Colapso.Texts;
