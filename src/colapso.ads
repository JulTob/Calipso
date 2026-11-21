--  Colapso: generar texto rellenando huecos, mirando el contexto a ambos lados.
--
--  Este paquete raíz solo define el vocabulario común a todos los demás.

package Colapso is

    pragma Pure;

    Max_Symbols : constant := 255;

    type Symbol_Count is range 0 .. Max_Symbols;
    --# Para contar símbolos: de 0 (ninguno) a 255.

    subtype Symbol is Symbol_Count range 1 .. Max_Symbols;
    --# Un símbolo es un número pequeño que representa una letra.
    --# Trabajar con números en vez de letras deja que todo lo demás
    --# (tablas, distribuciones) sean simples arrays indexados por símbolo.

    Unknown : constant Symbol := 1;
    --# El símbolo 1 se reserva para "letra que no conozco".

    end Colapso;
