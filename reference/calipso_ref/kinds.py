"""Mirror of Calipso.Kinds: the kinds of token ("syntokens").

The upper level of the pyramid does not see letters. It sees KINDS:

    a mark is its own kind                         "."  ","
    a number is known by how many digits it has    1, 2, 3, 4 or more
    a very usual word is its own kind              "the"  "of"
    any other word is known by its SHAPE:
        does it start with a capital? how long is it? how does it end?

A kind is a symbol, like a letter is: the same brains and the same engine work on both.
The book is the table token <-> kind. It is decided by reading a text once.
"""

from . import MAX_SYMBOLS, UNKNOWN
from . import random_sources
from . import tokens

MOST_MARKS = 40
MOST_WORDS = 120
MOST_ENDINGS = 10
ENDING_LENGTH = 2
SHORTEST_WITH_ENDING = 4
SIZE_GROUPS = 4
NUMBER_KINDS = 4
#-- 1 + 40 + 4 + 120 + 2 * 4 * (10 + 1) = 253 kinds at most: they fit in a symbol.

UNKNOWN_KIND = 0
MARK_KIND = 1
NUMBER_KIND = 2
WORD_KIND = 3
SHAPE_KIND = 4


class Kind_Note:
    #-- What one kind is.

    def __init__(self):
        self.family = UNKNOWN_KIND
        self.text = ""
        #-- The mark, the usual word, or the ending of a shape.
        self.figures = 0
        self.capital = False
        self.group = 0


class Tally:

    def __init__(
            self,
            text: str,
            first: int
            ):
        self.text = text
        self.seen = 0
        self.first = first
        #-- Its place in order of first appearance: it breaks ties when ranking.


class Tally_List:
    #-- How many times each text was seen, kept in order of first appearance.

    def __init__(self):
        self.items = []
        self.place_of = {}


class Member:

    def __init__(
            self,
            word: str,
            seen: int
            ):
        self.word = word
        self.seen = seen


class Book:

    def __init__(self):
        self.notes = [None, Kind_Note()]
        #-- notes[kind]. Position 0 is not used: Ada counts from 1. Kind 1 is "unknown".
        self.by_text = {}
        self.ending_place = {}
        self.first_number = UNKNOWN
        self.first_shape = UNKNOWN
        self.members = {}
        self.totals = {}


def Add_Amount(
        counts: Tally_List,
        text: str,
        amount: int
        ) -> None:
    if text not in counts.place_of:
        counts.place_of[text] = len(counts.items)
        counts.items.append(Tally(text, len(counts.items)))
    place = counts.place_of[text]
    counts.items[place].seen = counts.items[place].seen + amount


def Is_Before(
        left: Tally,
        right: Tally
        ) -> bool:
    #-- The most seen first. On a tie, the one that appeared first.
    if left.seen != right.seen:
        return left.seen > right.seen
    return left.first < right.first


def Ranked(
        counts: Tally_List
        ) -> list:
    return sorted(counts.items, key=lambda tally: (-tally.seen, tally.first))


def Word_Tallies(
        sample: list
        ) -> Tally_List:
    counts = Tally_List()
    for token in sample:
        if tokens.Sort_Of(token) == tokens.WORD:
            Add_Amount(counts, token, 1)
    return counts


def Kind_Count(
        book: Book
        ) -> int:
    return len(book.notes) - 1


def New_Kind(
        book: Book,
        note: Kind_Note
        ) -> int:
    book.notes.append(note)
    return Kind_Count(book)


def Note_Marks(
        book: Book,
        sample: list
        ) -> None:
    #-- Every mark is its own kind, in order of appearance, while there is room.
    taken = 0
    for token in sample:
        sort = tokens.Sort_Of(token)
        is_sign = sort == tokens.MARK or sort == tokens.BREAK
        if is_sign and token not in book.by_text and taken < MOST_MARKS:
            note = Kind_Note()
            note.family = MARK_KIND
            note.text = token
            book.by_text[token] = New_Kind(book, note)
            taken = taken + 1


def Note_Numbers(
        book: Book
        ) -> None:
    book.first_number = Kind_Count(book) + 1
    for figures in range(1, NUMBER_KINDS + 1):
        note = Kind_Note()
        note.family = NUMBER_KIND
        note.figures = figures
        New_Kind(book, note)


def Note_Words(
        book: Book,
        ranking: list
        ) -> None:
    #-- The most usual words are their own kind.
    for place in range(0, min(MOST_WORDS, len(ranking))):
        note = Kind_Note()
        note.family = WORD_KIND
        note.text = ranking[place].text
        book.by_text[note.text] = New_Kind(book, note)


def Has_Ending(
        word: str
        ) -> bool:
    return len(word) >= SHORTEST_WITH_ENDING


def Ending_Of_Word(
        word: str
        ) -> str:
    return word[len(word) - ENDING_LENGTH:].lower()


def Note_Endings(
        book: Book,
        words: Tally_List
        ) -> None:
    #-- The most usual endings among the words that are not their own kind.
    counts = Tally_List()
    for tally in words.items:
        if tally.text not in book.by_text and Has_Ending(tally.text):
            Add_Amount(counts, Ending_Of_Word(tally.text), tally.seen)
    ranking = Ranked(counts)
    for place in range(0, min(MOST_ENDINGS, len(ranking))):
        book.ending_place[ranking[place].text] = place + 1


def Note_Shapes(
        book: Book
        ) -> None:
    #-- One kind for every mix of capital, size and ending. Ending 0 means "none of the usual ones".
    book.first_shape = Kind_Count(book) + 1
    endings = [""] * (len(book.ending_place) + 1)
    for ending, place in book.ending_place.items():
        endings[place] = ending
    for capital in (False, True):
        for group in range(0, SIZE_GROUPS):
            for place in range(0, len(endings)):
                note = Kind_Note()
                note.family = SHAPE_KIND
                note.capital = capital
                note.group = group
                note.text = endings[place]
                New_Kind(book, note)


def Note_Members(
        book: Book,
        words: Tally_List
        ) -> None:
    #-- Which words were seen in each shape, and how often.
    for tally in words.items:
        if tally.text not in book.by_text:
            kind = Kind_Of(book, tally.text)
            book.members.setdefault(kind, []).append(Member(tally.text, tally.seen))
            book.totals[kind] = book.totals.get(kind, 0) + tally.seen


def Built(
        sample: list
        ) -> Book:
    #-- Reads a text once and decides the kinds.
    book = Book()
    words = Word_Tallies(sample)
    Note_Marks(book, sample)
    Note_Numbers(book)
    Note_Words(book, Ranked(words))
    Note_Endings(book, words)
    Note_Shapes(book)
    Note_Members(book, words)
    return book


def Group_Of(
        length: int
        ) -> int:
    if length <= 3:
        return 0
    if length <= 5:
        return 1
    if length <= 8:
        return 2
    return 3


def Ending_Place(
        book: Book,
        word: str
        ) -> int:
    if not Has_Ending(word):
        return 0
    return book.ending_place.get(Ending_Of_Word(word), 0)


def Shape_Kind(
        book: Book,
        word: str
        ) -> int:
    per_group = len(book.ending_place) + 1
    per_capital = SIZE_GROUPS * per_group
    capital = 1 if word[0].isupper() else 0
    return book.first_shape + capital * per_capital + Group_Of(len(word)) * per_group + Ending_Place(book, word)


def Kind_Of(
        book: Book,
        token: str
        ) -> int:
    sort = tokens.Sort_Of(token)
    if Kind_Count(book) == UNKNOWN:
        return UNKNOWN
        #-- A book that has read nothing knows no kinds.
    if sort == tokens.NUMBER:
        return book.first_number + min(len(token), NUMBER_KINDS) - 1
    if token in book.by_text:
        return book.by_text[token]
    if sort == tokens.WORD:
        return Shape_Kind(book, token)
    return UNKNOWN


def Family_Of(
        book: Book,
        kind: int
        ) -> int:
    return book.notes[kind].family


def Text_Of(
        book: Book,
        kind: int
        ) -> str:
    return book.notes[kind].text


def Figures_Of(
        book: Book,
        kind: int
        ) -> int:
    return book.notes[kind].figures


def Is_Capital(
        book: Book,
        kind: int
        ) -> bool:
    return book.notes[kind].capital


def Has_Members(
        book: Book,
        kind: int
        ) -> bool:
    return book.totals.get(kind, 0) > 0


def Draw_Member(
        book: Book,
        kind: int,
        dice: random_sources.Generator
        ) -> str:
    #-- One of the words seen in this kind. A word seen twice as often comes out twice as often.
    ticket = random_sources.Draw_Index(dice, book.totals[kind])
    for member in book.members[kind]:
        if ticket < member.seen:
            return member.word
        ticket = ticket - member.seen
    raise ValueError("the totals of the book do not add up")
