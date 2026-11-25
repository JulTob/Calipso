"""Mirror of Calipso.Settling: change one point, and let the rest find its place again.

The text is read from left to right. Each cell asks: "given my neighbours as they
are now, and given how sure I was of what I held, what should I be?" If the
answer is another symbol, the cell is rewritten. The text is read again and again
until a whole reading changes nothing. Such a text is a FIXED POINT: reading it
once more gives the same text.

A pinned change is a cell whose anchor is sure (1) of the new symbol. A cell
"surely wrong" (0) must change. Every other cell resists as much as its certainty says.
"""

from . import anchored_oracles
from . import canvases
from . import distributions
from . import oracles

DEFAULT_PASSES = 8


class Report:

    def __init__(self):
        self.passes = 0
        self.changes = 0
        #-- How many times a cell was rewritten.
        self.is_settled = False
        #-- A whole reading went by with no change.


def Written(
        text: list
        ) -> canvases.Canvas:
    #-- A canvas with the text on it, every cell free to be rewritten.
    board = canvases.Canvas()
    for symbol in text:
        canvases.Append_Blank(board)
        canvases.Guess(board, canvases.Length(board) - 1, symbol)
    return board


def Even_Anchors(
        text: list,
        sure: float
        ) -> list:
    #-- Every cell remembers its own symbol, all with the same certainty.
    anchors = []
    for symbol in text:
        anchors.append(anchored_oracles.Anchor_Of(symbol, sure))
    return anchors


def Revisit(
        board: canvases.Canvas,
        model: oracles.Oracle,
        position: int
        ) -> bool:
    #-- One cell decides again. Says whether it changed.
    best = distributions.Most_Likely(model.Opinion(board, position))
    if best == canvases.Symbol_At(board, position):
        return False
    canvases.Erase(board, position)
    canvases.Guess(board, position, best)
    return True


def Read_Once(
        board: canvases.Canvas,
        model: oracles.Oracle
        ) -> int:
    #-- One reading from left to right. Returns how many cells changed.
    changes = 0
    for position in range(0, canvases.Length(board)):
        if canvases.State_At(board, position) == canvases.GUESSED:
            if Revisit(board, model, position):
                changes = changes + 1
    return changes


def Settle(
        board: canvases.Canvas,
        model: oracles.Oracle,
        anchors: list,
        passes: int = DEFAULT_PASSES
        ) -> Report:
    anchored = anchored_oracles.Anchored_Oracle(model, anchors)
    outcome = Report()
    for _ in range(0, passes):
        changes = Read_Once(board, anchored)
        outcome.passes = outcome.passes + 1
        outcome.changes = outcome.changes + changes
        if changes == 0:
            outcome.is_settled = True
            break
    return outcome
