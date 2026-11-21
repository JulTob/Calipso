"""Referencia ejecutable de Colapso.

Cada módulo de esta carpeta es el espejo de un paquete Ada de `src/`:
mismo nombre, mismas funciones, mismos pasos y en el mismo orden.
Sirve para dos cosas:

  1. Probar la idea deprisa (aquí se ejecutan los experimentos).
  2. Comprobar el Ada: con la misma semilla, los dos deben dar lo mismo.
"""

MAX_SYMBOLS = 255
#-- Un símbolo es un número pequeño (1 .. 255) que representa una letra.

UNKNOWN = 1
#-- El símbolo 1 se reserva para "letra que no conozco".
