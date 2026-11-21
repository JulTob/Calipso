"""Espejo de Colapso.Alphabets: la tabla letra <-> símbolo."""

from . import MAX_SYMBOLS, UNKNOWN

UNKNOWN_MARK = "?"
#-- Cómo se pinta el símbolo desconocido.


class Alphabet:

    def __init__(self):
        self.size = 1
        self.table = [None, UNKNOWN_MARK]
        #-- table[símbolo] = letra. La posición 0 no se usa: en Ada se cuenta desde 1.


def Size(
        letters: Alphabet
        ) -> int:
    return letters.size


def Is_Full(
        letters: Alphabet
        ) -> bool:
    return letters.size == MAX_SYMBOLS


def Contains(
        letters: Alphabet,
        char: str
        ) -> bool:
    for symbol in range(2, letters.size + 1):
        if letters.table[symbol] == char:
            return True
    return False


def Include(
        letters: Alphabet,
        char: str
        ) -> None:
    #-- Añade la letra si es nueva y queda sitio. Si no, no hace nada.
    if Contains(letters, char):
        return
    if Is_Full(letters):
        return
    letters.size = letters.size + 1
    letters.table.append(char)


def Symbol_Of(
        letters: Alphabet,
        char: str
        ) -> int:
    for symbol in range(2, letters.size + 1):
        if letters.table[symbol] == char:
            return symbol
    return UNKNOWN


def Character_Of(
        letters: Alphabet,
        symbol: int
        ) -> str:
    if symbol > letters.size:
        raise ValueError("símbolo fuera del alfabeto")
    return letters.table[symbol]
