"""Mirror of Calipso.Voting_Oracles: a brain that learns.

Idea: every known neighbour VOTES. A vote is a row of points, for or against
each candidate letter. There is a different row of points for each pair
(distance to the hole, letter found there):

    "I have a 'q' right on your left"  ->  many points for 'u'

To give an opinion, the votes of all known neighbours are added up (holes do
not vote) and the points are turned into probabilities.

At the start every point is 0: the brain knows nothing. It learns by playing
the blind-spot game: a letter is hidden, it gives its opinion, it is shown
the real letter, and each neighbour that voted corrects its points a little.
"""

from . import blind_spots
from . import canvases
from . import distributions
from . import oracles
from . import random_sources
from . import templates

DEFAULT_REACH = 12
#-- Up to how many cells away a neighbour votes, on each side.


class Lesson_Plan:

    def __init__(self):
        self.lessons = 4000
        #-- How many pieces of text are studied.
        self.piece_length = 64
        self.learning_rate = 0.5
        #-- How much of the error is corrected on each letter: 0 = nothing, 1 = all at once.


class Voting_Oracle(oracles.Oracle):

    def __init__(self):
        self.letter_count = 1
        self.reach = DEFAULT_REACH
        self.bias = [0.0, 0.0]
        #-- bias[candidate]: starting points of each letter, without looking at anyone.
        self.votes = [0.0]
        #-- All the votes in one long row. See Slot_Of.

    def Alphabet_Size(self) -> int:
        return self.letter_count

    def Reach(self) -> int:
        return self.reach

    def Opinion(
            self,
            board: canvases.Canvas,
            position: int
            ) -> distributions.Distribution:
        scores = Scores_At(self, board, position)
        return distributions.From_Scores(scores)


def Slot_Of(
        model: Voting_Oracle,
        offset: int,
        neighbour: int,
        candidate: int
        ) -> int:
    #-- Place in the long row of the point (distance, neighbour letter, candidate letter).
    #-- Mirror note: in Ada the row starts at 1, so 1 is added at the end there.
    side = offset + model.reach
    row = side * model.letter_count + (neighbour - 1)
    return row * model.letter_count + (candidate - 1)


def Prepare(
        model: Voting_Oracle,
        letter_count: int,
        reach: int = DEFAULT_REACH
        ) -> None:
    #-- Leaves the brain blank: all points at 0.
    model.letter_count = letter_count
    model.reach = reach
    model.bias = [0.0] * (letter_count + 1)
    sides = 2 * reach + 1
    model.votes = [0.0] * (sides * letter_count * letter_count)


def Is_Voter(
        board: canvases.Canvas,
        position: int,
        offset: int
        ) -> bool:
    #-- Is there a neighbour with a letter at that distance?
    if offset == 0:
        return False
    neighbour = position + offset
    if neighbour < 0:
        return False
    if neighbour >= canvases.Length(board):
        return False
    return not canvases.Is_Blank(board, neighbour)


def Scores_At(
        model: Voting_Oracle,
        board: canvases.Canvas,
        position: int
        ) -> list:
    #-- Sum of votes for each candidate letter. scores[candidate]; position 0 is not used.
    scores = [0.0] * (model.letter_count + 1)
    for candidate in range(1, model.letter_count + 1):
        scores[candidate] = model.bias[candidate]
    for offset in range(-model.reach, model.reach + 1):
        if Is_Voter(board, position, offset):
            neighbour = canvases.Symbol_At(board, position + offset)
            first = Slot_Of(model, offset, neighbour, 1)
            for candidate in range(1, model.letter_count + 1):
                scores[candidate] = scores[candidate] + model.votes[first + candidate - 1]
    return scores


def Voter_Count(
        board: canvases.Canvas,
        position: int,
        reach: int
        ) -> int:
    count = 0
    for offset in range(-reach, reach + 1):
        if Is_Voter(board, position, offset):
            count = count + 1
    return count


def Learn_Cell(
        model: Voting_Oracle,
        board: canvases.Canvas,
        position: int,
        actual: int,
        learning_rate: float
        ) -> float:
    #-- A minimal lesson: give an opinion on a hidden cell, look at the real letter and correct.
    #-- Returns the surprise the real letter caused BEFORE correcting.
    belief = model.Opinion(board, position)
    surprise = distributions.Surprise_Of(belief, actual)
    voters = Voter_Count(board, position, model.reach)
    step = learning_rate / float(voters + 1)
    #-- The correction is shared equally among the neighbours that voted and the starting points.
    errors = [0.0] * (model.letter_count + 1)
    for candidate in range(1, model.letter_count + 1):
        errors[candidate] = distributions.Probability_Of(belief, candidate)
        #-- Each letter loses what was bet on it...
    errors[actual] = errors[actual] - 1.0
    #-- ...and the real letter gets what it was missing to reach 1.
    for candidate in range(1, model.letter_count + 1):
        model.bias[candidate] = model.bias[candidate] - step * errors[candidate]
    for offset in range(-model.reach, model.reach + 1):
        if Is_Voter(board, position, offset):
            neighbour = canvases.Symbol_At(board, position + offset)
            first = Slot_Of(model, offset, neighbour, 1)
            for candidate in range(1, model.letter_count + 1):
                slot = first + candidate - 1
                model.votes[slot] = model.votes[slot] - step * errors[candidate]
    return surprise


def Train(
        model: Voting_Oracle,
        text: list,
        dice: random_sources.Generator,
        plan: Lesson_Plan
        ) -> float:
    #-- Training = playing the blind-spot game many times.
    #-- Returns the mean surprise over the last tenth of the lessons.
    room = len(text) - plan.piece_length
    last_stretch = plan.lessons - plan.lessons // 10
    surprise_sum = 0.0
    cells = 0
    for lesson in range(0, plan.lessons):
        start = random_sources.Draw_Index(dice, room)
        original = templates.From_Text(text, start, plan.piece_length)
        board = canvases.Copy(original)
        rate = random_sources.Draw_Unit(dice)
        #-- Each lesson hides a different amount: sometimes almost nothing, sometimes almost everything.
        blind_spots.Hide_At_Random(board, rate, dice)
        for position in range(0, plan.piece_length):
            if canvases.Is_Blank(board, position):
                actual = canvases.Symbol_At(original, position)
                surprise = Learn_Cell(model, board, position, actual, plan.learning_rate)
                if lesson >= last_stretch:
                    surprise_sum = surprise_sum + surprise
                    cells = cells + 1
    if cells == 0:
        return 0.0
    return surprise_sum / float(cells)
