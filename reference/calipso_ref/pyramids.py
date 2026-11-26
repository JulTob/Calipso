"""Mirror of Calipso.Pyramids: writing from the top down, in two levels.

    Level of kinds  : a canvas whose cells are KINDS of token is collapsed. This is the plan:
                      "usual word, long word ending in -ed, comma, ..."
    Handover        : the plan is turned into a canvas of letters. Marks and usual words are
                      written as they are. Every other word becomes a BOX: holes that may
                      only hold letters, with the ending of its kind already written.
    Level of letters: the letter brain fills the boxes.

The engine and the brains are the ones the flat method uses. Nothing is new but
the order: a decision of one level is the template of the level below.
"""

from . import alphabets
from . import boxed_oracles
from . import canvases
from . import collapsing
from . import counting_oracles
from . import kind_makers
from . import kinds
from . import oracles
from . import random_sources
from . import tokens
from . import MAX_SYMBOLS

SPELL = 0
PICK = 1
#-- How a word that is not usual becomes letters:
#--   SPELL: the letter brain writes it, inside a box of the right size and ending.
#--   PICK : a word of that kind is taken from the words seen while studying.

DEFAULT_LONGEST = 5
#-- The widest run of kinds the plan level looks at.

STOP_MARK = "."
OPENING_MARKS = "(["
GLUE_MARKS = "-'"
FALLBACK_LENGTH = 4
#-- The size of the box of a kind no word was ever seen in.

AT_START = 0
AFTER_OPENING = 1
AFTER_GLUE = 2
AFTER_BREAK = 3
AFTER_MARK = 4
AFTER_WORD = 5


class Pyramid:

    def __init__(self):
        self.book = kinds.Book()
        self.brain = counting_oracles.Counting_Oracle()


def Kind_Text(
        book: kinds.Book,
        sample: list
        ) -> list:
    kind_text = []
    for token in sample:
        kind_text.append(kinds.Kind_Of(book, token))
    return kind_text


def Study(
        pyramid: Pyramid,
        text: str,
        options: kind_makers.Settings = None
        ) -> None:
    #-- Reads the text as tokens, decides the kinds, and counts how kinds follow each other.
    #-- `options` says how the kinds are decided: by shape if nothing is said.
    sample = tokens.Split(text)
    if options is None:
        options = kind_makers.Settings()
    pyramid.book = kind_makers.Book_Of(sample, options)
    kind_text = Kind_Text(pyramid.book, sample)
    counting_oracles.Train(pyramid.brain, kind_text, kinds.Kind_Count(pyramid.book), DEFAULT_LONGEST)


def Blank_Plan(
        pyramid: Pyramid,
        size: int
        ) -> canvases.Canvas:
    #-- `size` kinds to decide, between two full stops when the text has them.
    stop = kinds.Kind_Of(pyramid.book, STOP_MARK)
    plan = canvases.Canvas()
    if stop != 1:
        canvases.Append_Given(plan, stop)
    for _ in range(0, size):
        canvases.Append_Blank(plan)
    if stop != 1:
        canvases.Append_Given(plan, stop)
    return plan


class Letter_Rules:
    #-- The three permissions a box uses, worked out once from the alphabet.

    def __init__(self):
        self.small = boxed_oracles.Free_Rule()
        self.capital = boxed_oracles.Free_Rule()
        self.figure = boxed_oracles.Free_Rule()


def Is_Small_Letter(
        char: str
        ) -> bool:
    return tokens.Is_Letter(char) and not char.isupper()


def Is_Capital_Letter(
        char: str
        ) -> bool:
    return char.isupper()


def Rule_For(
        letters: alphabets.Alphabet,
        belongs
        ) -> boxed_oracles.Cell_Rule:
    allowed = [False] * (MAX_SYMBOLS + 1)
    for symbol in range(2, alphabets.Size(letters) + 1):
        allowed[symbol] = belongs(alphabets.Character_Of(letters, symbol))
    return boxed_oracles.Rule_Of(allowed)


def Rules_Of(
        letters: alphabets.Alphabet
        ) -> Letter_Rules:
    rules = Letter_Rules()
    rules.small = Rule_For(letters, Is_Small_Letter)
    rules.capital = Rule_For(letters, Is_Capital_Letter)
    rules.figure = Rule_For(letters, tokens.Is_Digit)
    return rules


class Draft:
    #-- A canvas of letters being prepared: the cells, the rule of each cell, and what was put last.

    def __init__(self):
        self.board = canvases.Canvas()
        self.rules = []
        self.last = AT_START


def Put_Given(
        draft: Draft,
        letters: alphabets.Alphabet,
        plain: str
        ) -> None:
    for char in plain:
        canvases.Append_Given(draft.board, alphabets.Symbol_Of(letters, char))
        draft.rules.append(boxed_oracles.Free_Rule())


def Put_Hole(
        draft: Draft,
        rule: boxed_oracles.Cell_Rule
        ) -> None:
    canvases.Append_Blank(draft.board)
    draft.rules.append(rule)


def Put_Space_If_Needed(
        draft: Draft,
        letters: alphabets.Alphabet
        ) -> None:
    #-- A word is set apart from what came before, except at the start, after "(" and after "-".
    if draft.last == AFTER_MARK or draft.last == AFTER_WORD:
        Put_Given(draft, letters, " ")


def Put_Mark(
        draft: Draft,
        letters: alphabets.Alphabet,
        mark: str
        ) -> None:
    if mark == tokens.BREAK_TEXT:
        Put_Given(draft, letters, mark)
        draft.last = AFTER_BREAK
    elif mark in OPENING_MARKS:
        Put_Space_If_Needed(draft, letters)
        Put_Given(draft, letters, mark)
        draft.last = AFTER_OPENING
    elif mark in GLUE_MARKS:
        Put_Given(draft, letters, mark)
        draft.last = AFTER_GLUE
    else:
        Put_Given(draft, letters, mark)
        draft.last = AFTER_MARK


def Put_Number(
        draft: Draft,
        rules: Letter_Rules,
        figures: int
        ) -> None:
    for _ in range(0, figures):
        Put_Hole(draft, rules.figure)


def Put_Box(
        draft: Draft,
        letters: alphabets.Alphabet,
        rules: Letter_Rules,
        length: int,
        capital: bool,
        ending: str
        ) -> None:
    #-- Holes for the letters the brain will write, then the ending of the kind.
    for index in range(0, length - len(ending)):
        if index == 0 and capital:
            Put_Hole(draft, rules.capital)
        else:
            Put_Hole(draft, rules.small)
    Put_Given(draft, letters, ending)


def Put_Shape(
        draft: Draft,
        book: kinds.Book,
        letters: alphabets.Alphabet,
        rules: Letter_Rules,
        dice: random_sources.Generator,
        passing: int,
        kind: int
        ) -> None:
    capital = kinds.Is_Capital(book, kind)
    ending = kinds.Text_Of(book, kind)
    if not kinds.Has_Members(book, kind):
        Put_Box(draft, letters, rules, FALLBACK_LENGTH, capital, ending)
        return
    member = kinds.Draw_Member(book, kind, dice)
    if passing == PICK:
        Put_Given(draft, letters, member)
    else:
        Put_Box(draft, letters, rules, len(member), capital, ending)
        #-- Of the word drawn, only the length is kept: the letters are the brain's to choose.


def Put_Kind(
        draft: Draft,
        book: kinds.Book,
        letters: alphabets.Alphabet,
        rules: Letter_Rules,
        dice: random_sources.Generator,
        passing: int,
        kind: int
        ) -> None:
    family = kinds.Family_Of(book, kind)
    if family == kinds.UNKNOWN_KIND:
        return
    if family == kinds.MARK_KIND:
        Put_Mark(draft, letters, kinds.Text_Of(book, kind))
        return
    Put_Space_If_Needed(draft, letters)
    if family == kinds.WORD_KIND:
        Put_Given(draft, letters, kinds.Text_Of(book, kind))
    elif family == kinds.NUMBER_KIND:
        Put_Number(draft, rules, kinds.Figures_Of(book, kind))
    else:
        Put_Shape(draft, book, letters, rules, dice, passing, kind)
    draft.last = AFTER_WORD


def Draft_Of(
        pyramid: Pyramid,
        plan: canvases.Canvas,
        letters: alphabets.Alphabet,
        dice: random_sources.Generator,
        passing: int
        ) -> Draft:
    #-- The handover: every kind of the plan becomes given letters or a box of holes.
    rules = Rules_Of(letters)
    draft = Draft()
    first = 0
    if kinds.Kind_Of(pyramid.book, STOP_MARK) != 1:
        first = 1
        #-- The opening full stop only gave the plan a start: it is not written.
    for position in range(first, canvases.Length(plan)):
        Put_Kind(draft, pyramid.book, letters, rules, dice, passing, canvases.Symbol_At(plan, position))
    return draft


def Plain_Text(
        board: canvases.Canvas,
        letters: alphabets.Alphabet
        ) -> str:
    plain = ""
    for position in range(0, canvases.Length(board)):
        plain = plain + alphabets.Character_Of(letters, canvases.Symbol_At(board, position))
    return plain


def Write(
        pyramid: Pyramid,
        speller: oracles.Oracle,
        letters: alphabets.Alphabet,
        dice: random_sources.Generator,
        size: int,
        passing: int
        ) -> str:
    plan = Blank_Plan(pyramid, size)
    collapsing.Collapse_All(plan, pyramid.brain, dice)
    draft = Draft_Of(pyramid, plan, letters, dice, passing)
    boxed = boxed_oracles.Boxed_Oracle(speller, draft.rules)
    collapsing.Collapse_All(draft.board, boxed, dice)
    return Plain_Text(draft.board, letters)
