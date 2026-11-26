"""Mirror of Calipso.Word_Exams: an exam for the level of kinds.

In a text never studied, one word in every few is hidden. The level of kinds
looks at the kinds of the four tokens on each side and gives its opinion of the
kind of the hidden word. Then the most usual studied word of that length, in
the most likely kind, is the answer. The exam counts how often it is the word
that was hidden.

It measures the kinds, not the letters: a better way of deciding kinds scores higher.
"""

from . import canvases
from . import distributions
from . import kinds
from . import pyramids
from . import tokens

DEFAULT_STEP = 9
SIDE = 4


class Result:

    def __init__(self):
        self.asked = 0
        self.right = 0


class Known_Words:
    #-- Every different word of the studied text, with what the exam needs to know about it.

    def __init__(self):
        self.words = []
        self.place_of = {}
        self.seen = []
        self.kind = []
        self.kind_total = {}
        #-- kind_total[kind]: how many times a word of that kind was seen.


def Known_From(
        book: kinds.Book,
        studied: list
        ) -> Known_Words:
    known = Known_Words()
    for token in studied:
        if tokens.Sort_Of(token) == tokens.WORD:
            if token not in known.place_of:
                known.place_of[token] = len(known.words)
                known.words.append(token)
                known.seen.append(0)
                known.kind.append(kinds.Kind_Of(book, token))
            place = known.place_of[token]
            known.seen[place] = known.seen[place] + 1
    for place in range(0, len(known.words)):
        kind = known.kind[place]
        known.kind_total[kind] = known.kind_total.get(kind, 0) + known.seen[place]
    return known


def Kinds_Around(
        book: kinds.Book,
        unseen: list,
        place: int
        ) -> canvases.Canvas:
    #-- A canvas of kinds: SIDE given kinds, one hole, SIDE given kinds.
    board = canvases.Canvas()
    for near in range(place - SIDE, place + SIDE + 1):
        if near == place:
            canvases.Append_Blank(board)
        else:
            canvases.Append_Given(board, kinds.Kind_Of(book, unseen[near]))
    return board


def Best_Word(
        known: Known_Words,
        belief: distributions.Distribution,
        length: int
        ) -> str:
    #-- The studied word of this length that the opinion makes most likely. "" if there is none.
    best = ""
    best_weight = -1.0
    for place in range(0, len(known.words)):
        if len(known.words[place]) == length:
            kind = known.kind[place]
            share = float(known.seen[place]) / float(known.kind_total[kind])
            weight = distributions.Weight_Of(belief, kind) * share
            if weight > best_weight:
                best = known.words[place]
                best_weight = weight
    return best


def Exam(
        plan: pyramids.Pyramid,
        studied: list,
        unseen: list,
        step: int = DEFAULT_STEP
        ) -> Result:
    result = Result()
    known = Known_From(plan.book, studied)
    place = SIDE
    while place < len(unseen) - SIDE:
        truth = unseen[place]
        if tokens.Sort_Of(truth) == tokens.WORD:
            board = Kinds_Around(plan.book, unseen, place)
            belief = plan.brain.Opinion(board, SIDE)
            result.asked = result.asked + 1
            if Best_Word(known, belief, len(truth)) == truth:
                result.right = result.right + 1
        place = place + step
    return result
