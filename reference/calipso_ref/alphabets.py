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


COMMON_LETTER_NUMBERS = [
    10,
    #-- The line feed.
    32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,
    48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63,
    64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79,
    80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95,
    96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111,
    112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126,
    #-- The space, and the visible characters of the basic set: A-Z a-z 0-9 and punctuation.
    225, 233, 237, 243, 250, 252, 241, 193, 201, 205, 211, 218, 220, 209, 191, 161,
    #-- Spanish: accented vowels, u with dots, n with tilde, opening question and exclamation marks.
    224, 232, 236, 242, 249, 226, 234, 238, 244, 251, 228, 235, 239, 246, 231, 227, 245, 223,
    #-- Other accented letters of western Europe.
    8211, 8212, 8216, 8217, 8220, 8221, 8230, 171, 187, 8364, 183, 186, 170,
    #-- Printing marks: dashes, curly quotes, three dots, angle quotes, euro, middle dot, ordinals.
    ]
#-- Each letter by its Unicode number, so that this file needs nothing but plain characters.


def Common_Letters() -> Alphabet:
    #-- A ready-made alphabet for western text, for when the text is not known beforehand.
    letters = Alphabet()
    for number in COMMON_LETTER_NUMBERS:
        Include(letters, chr(number))
    return letters
