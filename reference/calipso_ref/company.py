"""Mirror of Calipso.Company: a word described by the company it keeps.

For every word, count what stands around it: one count for each (distance,
side, neighbour). That list of counts is the word's vector. Two words that keep
the same company get vectors that point the same way.

The settings decide what "company" means:

    reach       how many tokens are looked at on each side (1 = the nearest only)
    context     AS_KINDS: a neighbour counts as its KIND (usual words as themselves,
                the others by shape). Coarse: it finds grammar.
                AS_WORDS: a neighbour counts as the WORD it is, hashed into a fixed
                number of buckets. Fine: it finds groups like "things that eat grass".
    fold_case   "Zebras" and "zebras" are one word
    every_word  False: words that are already their own kind are left out
    soften      counts are passed through log (1 + count) and the vector is made
                of length 1, so that very usual neighbours do not drown the rest

The first half of a vector is what stands BEFORE the word and the second half
what stands AFTER it: the two halves the complex product needs.
"""

import math

from . import kinds
from . import tokens
from . import vectors

AS_KINDS = 0
AS_WORDS = 1
DEFAULT_BUCKETS = 256
HASH_START = 2166136261
HASH_PRIME = 16777619
HASH_LIMIT = 4294967296


class Settings:

    def __init__(self):
        self.reach = 1
        self.context = AS_KINDS
        self.buckets = DEFAULT_BUCKETS
        self.fold_case = True
        self.every_word = False
        self.soften = True


class Table:

    def __init__(self):
        self.settings = Settings()
        self.size = 0
        #-- How many different neighbours can be told apart at one distance on one side.
        self.words = []
        self.row_of = {}
        self.rows = []
        self.seen = []


def Hash_Of(
        text: str
        ) -> int:
    #-- A scrambled number for a word (FNV-1a over its characters).
    scrambled = HASH_START
    for char in text:
        scrambled = ((scrambled ^ ord(char)) * HASH_PRIME) % HASH_LIMIT
    return scrambled


def Folded(
        settings: Settings,
        word: str
        ) -> str:
    if settings.fold_case:
        return word.lower()
    return word


def Context_Size(
        book: kinds.Book,
        settings: Settings
        ) -> int:
    if settings.context == AS_KINDS:
        return kinds.Kind_Count(book)
    return settings.buckets


def Code_Of(
        book: kinds.Book,
        settings: Settings,
        token: str
        ) -> int:
    #-- The number a neighbour is counted under, from 1 to Context_Size.
    if settings.context == AS_KINDS:
        return kinds.Kind_Of(book, token)
    return 1 + Hash_Of(Folded(settings, token)) % settings.buckets


def Is_Counted(
        book: kinds.Book,
        settings: Settings,
        token: str
        ) -> bool:
    if tokens.Sort_Of(token) != tokens.WORD:
        return False
    if settings.every_word:
        return True
    return kinds.Family_Of(book, kinds.Kind_Of(book, token)) != kinds.WORD_KIND


def Row_For(
        table: Table,
        key: str
        ) -> int:
    #-- The row of this word, made (all zeros) the first time the word is met.
    if key not in table.row_of:
        table.row_of[key] = len(table.words)
        table.words.append(key)
        table.rows.append([0.0] * (2 * table.settings.reach * table.size))
        table.seen.append(0)
    return table.row_of[key]


def Count_Neighbours(
        table: Table,
        book: kinds.Book,
        sample: list,
        place: int,
        row: int
        ) -> None:
    reach = table.settings.reach
    for step in range(1, reach + 1):
        if place - step >= 0:
            feature = (step - 1) * table.size + Code_Of(book, table.settings, sample[place - step])
            table.rows[row][feature - 1] = table.rows[row][feature - 1] + 1.0
        if place + step < len(sample):
            feature = (reach + step - 1) * table.size + Code_Of(book, table.settings, sample[place + step])
            table.rows[row][feature - 1] = table.rows[row][feature - 1] + 1.0


def Softened(
        row: list
        ) -> list:
    eased = []
    for count in row:
        eased.append(math.log(1.0 + count))
    return vectors.Unit(eased)


def Built(
        sample: list,
        book: kinds.Book,
        settings: Settings
        ) -> Table:
    table = Table()
    table.settings = settings
    table.size = Context_Size(book, settings)
    for place in range(0, len(sample)):
        if Is_Counted(book, settings, sample[place]):
            row = Row_For(table, Folded(settings, sample[place]))
            table.seen[row] = table.seen[row] + 1
            Count_Neighbours(table, book, sample, place, row)
    if settings.soften:
        for row in range(0, len(table.rows)):
            table.rows[row] = Softened(table.rows[row])
    return table


def Row_Count(table: Table) -> int:
    return len(table.words)


def Has_Word(table: Table, word: str) -> bool:
    return Folded(table.settings, word) in table.row_of


def Row_Of(table: Table, word: str) -> int:
    #-- Rows are counted from 1, as in Ada.
    return table.row_of[Folded(table.settings, word)] + 1


def Vector_At(table: Table, row: int) -> list:
    return table.rows[row - 1]


def Word_At(table: Table, row: int) -> str:
    return table.words[row - 1]


def Seen_At(table: Table, row: int) -> int:
    return table.seen[row - 1]


def Vector_Of(table: Table, word: str) -> list:
    return Vector_At(table, Row_Of(table, word))
