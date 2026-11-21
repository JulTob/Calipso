"""Espejo de Colapso.Fragment_Counts: cuántas veces aparece cada trocito.

Un fragmento es un trocito corto de texto (unas pocas letras seguidas).
Toda la "memoria" del modelo de conteo es esta tabla:
fragmento -> número de veces que se ha visto en el corpus.
"""


class Count_Table:

    def __init__(self):
        self.counts = {}
        #-- Clave: fragmento como `bytes` (un byte por símbolo). Valor: veces visto.


def Slice(
        text: list,
        first: int,
        length: int
        ) -> bytes:
    #-- El fragmento de `length` símbolos que empieza en `first`.
    piece = text[first:first + length]
    return bytes(piece)


def Add_One(
        table: Count_Table,
        piece: bytes
        ) -> None:
    seen = table.counts.get(piece, 0)
    table.counts[piece] = seen + 1


def Count_Of(
        table: Count_Table,
        piece: bytes
        ) -> int:
    return table.counts.get(piece, 0)


def Distinct_Fragments(
        table: Count_Table
        ) -> int:
    return len(table.counts)


def Learn(
        table: Count_Table,
        text: list,
        longest: int
        ) -> None:
    #-- Recorre el texto y apunta todos los fragmentos de 1 a `longest` letras.
    last = len(text) - 1
    for start in range(0, last + 1):
        for length in range(1, longest + 1):
            if start + length - 1 > last:
                break
            piece = Slice(text, start, length)
            Add_One(table, piece)
