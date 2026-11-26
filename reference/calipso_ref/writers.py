"""Mirror of Calipso.Writers: one contract, two ways of writing.

    Flat_Writer    : one level. Every cell is a letter and all are holes.
    Pyramid_Writer : two levels. First the kinds of word, then the letters.

A program asks a Writer for a text and does not need to know which one it has.
"""

from . import alphabets
from . import canvases
from . import collapsing
from . import oracles
from . import pyramids
from . import random_sources

LETTERS_PER_WORD = 6
#-- A word and its space, more or less: how the flat writer turns "words" into cells.
STOP_MARK = "."


class Writer:

    def Write(
            self,
            dice: random_sources.Generator,
            words: int
            ) -> str:
        #-- A text of about `words` words.
        raise NotImplementedError


class Flat_Writer(Writer):

    def __init__(
            self,
            speller: oracles.Oracle,
            letters: alphabets.Alphabet
            ):
        self.speller = speller
        self.letters = letters

    def Write(
            self,
            dice: random_sources.Generator,
            words: int
            ) -> str:
        board = canvases.Canvas()
        for _ in range(0, words * LETTERS_PER_WORD - 1):
            canvases.Append_Blank(board)
        if alphabets.Contains(self.letters, STOP_MARK):
            canvases.Append_Given(board, alphabets.Symbol_Of(self.letters, STOP_MARK))
        else:
            canvases.Append_Blank(board)
        collapsing.Collapse_All(board, self.speller, dice)
        return pyramids.Plain_Text(board, self.letters)


class Pyramid_Writer(Writer):

    def __init__(
            self,
            plan: pyramids.Pyramid,
            speller: oracles.Oracle,
            letters: alphabets.Alphabet,
            passing: int
            ):
        self.plan = plan
        self.speller = speller
        self.letters = letters
        self.passing = passing

    def Write(
            self,
            dice: random_sources.Generator,
            words: int
            ) -> str:
        return pyramids.Write(self.plan, self.speller, self.letters, dice, words, self.passing)
