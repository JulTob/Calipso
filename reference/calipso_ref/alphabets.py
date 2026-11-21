"""Mirror of Calipso.Alphabets: the letter <-> symbol table."""

from . import MAX_SYMBOLS, UNKNOWN

UNKNOWN_MARK = "?"
#-- How the unknown symbol is drawn.


class Alphabet:

    def __init__(self):
        self.size = 1
        self.table = [None, UNKNOWN_MARK]
        #-- table[symbol] = letter. Position 0 is not used: Ada counts from 1.


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
    #-- Adds the letter if it is new and there is room. Otherwise it does nothing.
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
        raise ValueError("symbol outside the alphabet")
    return letters.table[symbol]
