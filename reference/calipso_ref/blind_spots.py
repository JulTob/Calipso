"""Mirror of Calipso.Blind_Spots: the blind-spot experiment.

Take real text, hide letters at random and ask the model to fill them in.
Since we know the answer, we can count hits.

With the counting brain this is an EXAM. With a brain that learns, this
same game is the TRAINING: hide, bet, uncover and correct.
"""

from . import canvases
from . import distributions
from . import oracles
from . import random_sources
from . import templates


class Score:

    def __init__(self):
        self.hidden = 0
        self.recovered = 0


def Hide_At_Random(
        board: canvases.Canvas,
        rate: float,
        dice: random_sources.Generator
        ) -> None:
    #-- Each given letter is hidden with probability `rate`.
    for position in range(0, canvases.Length(board)):
        if canvases.State_At(board, position) == canvases.GIVEN:
            unit = random_sources.Draw_Unit(dice)
            if unit < rate:
                canvases.Hide(board, position)


def Scored(
        filled: canvases.Canvas,
        original: canvases.Canvas
        ) -> Score:
    #-- Compares the filled canvas with the original, cell by cell.
    score = Score()
    for position in range(0, canvases.Length(filled)):
        if canvases.State_At(filled, position) == canvases.GUESSED:
            score.hidden = score.hidden + 1
            if canvases.Symbol_At(filled, position) == canvases.Symbol_At(original, position):
                score.recovered = score.recovered + 1
    return score


class Exam_Result:

    def __init__(self):
        self.hidden = 0
        self.hits = 0
        self.surprise_sum = 0.0


def Added(
        left: Exam_Result,
        right: Exam_Result
        ) -> Exam_Result:
    #-- The score of two exams taken one after the other. (In Ada this is the operator "+".)
    total = Exam_Result()
    total.hidden = left.hidden + right.hidden
    total.hits = left.hits + right.hits
    total.surprise_sum = left.surprise_sum + right.surprise_sum
    return total


def Mean_Surprise(
        result: Exam_Result
        ) -> float:
    if result.hidden == 0:
        return 0.0
    return result.surprise_sum / float(result.hidden)


def Examine(
        model: oracles.Oracle,
        text: list,
        dice: random_sources.Generator,
        pieces: int,
        piece_length: int,
        rate: float
        ) -> Exam_Result:
    #-- The same exam for any brain: hide letters at random in pieces of
    #-- text and ask about each hidden letter, WITHOUT filling in the others.
    #-- It measures two things: how many it gets right and how much the real letter surprises it.
    result = Exam_Result()
    room = len(text) - piece_length
    for _ in range(0, pieces):
        start = random_sources.Draw_Index(dice, room)
        original = templates.From_Text(text, start, piece_length)
        board = canvases.Copy(original)
        Hide_At_Random(board, rate, dice)
        for position in range(0, piece_length):
            if canvases.Is_Blank(board, position):
                belief = model.Opinion(board, position)
                actual = canvases.Symbol_At(original, position)
                result.hidden = result.hidden + 1
                result.surprise_sum = result.surprise_sum + distributions.Surprise_Of(belief, actual)
                if distributions.Most_Likely(belief) == actual:
                    result.hits = result.hits + 1
    return result
