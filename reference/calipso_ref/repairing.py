"""Mirror of Calipso.Repairing: find what does not fit and fix it.

After collapsing, each letter can be examined: "if I hide you, would your
neighbours have guessed you?". If the answer is "not even close", that letter
is surprising: the text does not fit there.

  Surprise : how strange a letter looks to its neighbours (in nats).
  Tension  : sum of the surprise that goes over what is tolerable, in the
             zone the model has touched. Tension 0 = "everything fits".

Relaxing the canvas = repeat: find the most surprising letter, reopen its
surroundings and collapse again. If the same room does not improve it, try
WIDENING: put new cells in there. So the text grows only where it is needed.
"""

from . import canvases
from . import collapsing
from . import distributions
from . import oracles
from . import random_sources


class Settings:

    def __init__(self):
        self.tolerance = 4.0
        #-- Tolerable surprise per letter, in nats. 4 nats = "happens 1 time in 55".
        self.max_rounds = 40
        self.radius = 4
        #-- When reopening, how many cells on each side of the focus become holes again.
        self.extra_cells = 3
        #-- When widening, how many new cells are put in.
        self.max_length = 2000
        self.can_grow = True


class Report:

    def __init__(self):
        self.rounds = 0
        self.reopenings = 0
        self.widenings = 0
        self.final_tension = 0.0


def Surprise_At(
        board: canvases.Canvas,
        model: oracles.Oracle,
        position: int
        ) -> float:
    belief = model.Opinion(board, position)
    actual = canvases.Symbol_At(board, position)
    return distributions.Surprise_Of(belief, actual)


def Is_Influenced(
        board: canvases.Canvas,
        position: int,
        reach: int
        ) -> bool:
    #-- Is there any letter decided by the model within reach of this cell?
    first = max(0, position - reach)
    last = min(canvases.Length(board) - 1, position + reach)
    for neighbour in range(first, last + 1):
        if canvases.State_At(board, neighbour) == canvases.GUESSED:
            return True
    return False


def Is_Measured(
        board: canvases.Canvas,
        position: int,
        reach: int
        ) -> bool:
    if canvases.Is_Blank(board, position):
        return False
    return Is_Influenced(board, position, reach)


def Tension(
        board: canvases.Canvas,
        model: oracles.Oracle,
        tolerance: float
        ) -> float:
    result = 0.0
    reach = model.Reach()
    for position in range(0, canvases.Length(board)):
        if Is_Measured(board, position, reach):
            surprise = Surprise_At(board, model, position)
            if surprise > tolerance:
                result = result + (surprise - tolerance)
    return result


def Most_Surprising_Cell(
        board: canvases.Canvas,
        model: oracles.Oracle
        ) -> int:
    #-- The measured cell that surprises the most. -1 if there is none (in Ada: 0).
    best = -1
    best_surprise = 0.0
    reach = model.Reach()
    for position in range(0, canvases.Length(board)):
        if Is_Measured(board, position, reach):
            surprise = Surprise_At(board, model, position)
            if best < 0 or surprise > best_surprise:
                best = position
                best_surprise = surprise
    return best


def Nearest_Guess(
        board: canvases.Canvas,
        position: int
        ) -> int:
    #-- The nearest letter decided by the model. At equal distance, the one on the left.
    for distance in range(0, canvases.Length(board)):
        left = position - distance
        right = position + distance
        if left >= 0 and canvases.State_At(board, left) == canvases.GUESSED:
            return left
        if right < canvases.Length(board) and canvases.State_At(board, right) == canvases.GUESSED:
            return right
    raise ValueError("there are no letters decided by the model")


def Reopen_Around(
        board: canvases.Canvas,
        focus: int,
        radius: int
        ) -> None:
    #-- Turns the model's letters near the focus back into holes. Given letters are not touched.
    first = max(0, focus - radius)
    last = min(canvases.Length(board) - 1, focus + radius)
    for position in range(first, last + 1):
        if canvases.State_At(board, position) == canvases.GUESSED:
            canvases.Erase(board, position)


def Widen_At(
        board: canvases.Canvas,
        focus: int,
        extra: int
        ) -> None:
    for _ in range(0, extra):
        canvases.Insert_Blank(board, focus)


def Attempt_Repair(
        board: canvases.Canvas,
        model: oracles.Oracle,
        dice: random_sources.Generator,
        options: Settings,
        focus: int,
        extra: int,
        current: float
        ) -> float:
    #-- Tries a fix on a copy. If the tension goes down, it is kept; if not, it is thrown away.
    #-- Returns the tension the canvas is left with.
    candidate = canvases.Copy(board)
    Reopen_Around(candidate, focus, options.radius)
    Widen_At(candidate, focus, extra)
    collapsing.Collapse_All(candidate, model, dice)
    candidate_tension = Tension(candidate, model, options.tolerance)
    if candidate_tension < current:
        canvases.Assign(board, candidate)
        return candidate_tension
    return current


def May_Grow(
        board: canvases.Canvas,
        options: Settings
        ) -> bool:
    if not options.can_grow:
        return False
    return canvases.Length(board) + options.extra_cells <= options.max_length


def Relax(
        board: canvases.Canvas,
        model: oracles.Oracle,
        dice: random_sources.Generator,
        options: Settings
        ) -> Report:
    report = Report()
    current = Tension(board, model, options.tolerance)
    for _ in range(0, options.max_rounds):
        if current <= 0.0:
            break
        report.rounds = report.rounds + 1
        worst = Most_Surprising_Cell(board, model)
        focus = Nearest_Guess(board, worst)
        before = current
        current = Attempt_Repair(board, model, dice, options, focus, 0, current)
        #-- First attempt: same room, other letters.
        if current < before:
            report.reopenings = report.reopenings + 1
        elif May_Grow(board, options):
            current = Attempt_Repair(board, model, dice, options, focus, options.extra_cells, current)
            #-- Second attempt: more room.
            if current < before:
                report.widenings = report.widenings + 1
    report.final_tension = current
    return report
