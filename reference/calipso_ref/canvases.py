"""Mirror of Calipso.Canvases: the canvas where the text is written.

A canvas is a row of cells. Each cell is in one of three states:

  BLANK   : a hole. It can still be any letter ("superposition").
  GIVEN   : a letter given by the person. It is fixed evidence: never touched.
  GUESSED : a letter decided by the model. It can be reopened and decided again.

Mirror note: positions start at 0 here; in Ada they start at 1.
"""

from . import UNKNOWN

BLANK = 0
GIVEN = 1
GUESSED = 2


class Canvas:

    def __init__(self):
        self.states = []
        self.values = []


def Copy(
        board: Canvas
        ) -> Canvas:
    #-- In Ada this is a plain assignment: `Candidate := Board;`
    duplicate = Canvas()
    duplicate.states = list(board.states)
    duplicate.values = list(board.values)
    return duplicate


def Assign(
        target: Canvas,
        source: Canvas
        ) -> None:
    #-- In Ada this is `Board := Candidate;`
    target.states = list(source.states)
    target.values = list(source.values)


def Length(
        board: Canvas
        ) -> int:
    return len(board.states)


def State_At(
        board: Canvas,
        position: int
        ) -> int:
    return board.states[position]


def Is_Blank(
        board: Canvas,
        position: int
        ) -> bool:
    return board.states[position] == BLANK


def Symbol_At(
        board: Canvas,
        position: int
        ) -> int:
    if Is_Blank(board, position):
        raise ValueError("a hole has no letter")
    return board.values[position]


def Blank_Count(
        board: Canvas
        ) -> int:
    result = 0
    for position in range(0, Length(board)):
        if Is_Blank(board, position):
            result = result + 1
    return result


def Guess_Count(
        board: Canvas
        ) -> int:
    result = 0
    for position in range(0, Length(board)):
        if State_At(board, position) == GUESSED:
            result = result + 1
    return result


def Append_Given(
        board: Canvas,
        value: int
        ) -> None:
    board.states.append(GIVEN)
    board.values.append(value)


def Append_Blank(
        board: Canvas
        ) -> None:
    board.states.append(BLANK)
    board.values.append(UNKNOWN)


def Guess(
        board: Canvas,
        position: int,
        value: int
        ) -> None:
    #-- Collapse a cell: the hole now has a decided letter.
    if not Is_Blank(board, position):
        raise ValueError("only a hole can be collapsed")
    board.states[position] = GUESSED
    board.values[position] = value


def Erase(
        board: Canvas,
        position: int
        ) -> None:
    #-- Reopen a cell decided by the model. Given cells cannot be erased.
    if State_At(board, position) != GUESSED:
        raise ValueError("only a letter decided by the model can be reopened")
    board.states[position] = BLANK
    board.values[position] = UNKNOWN


def Hide(
        board: Canvas,
        position: int
        ) -> None:
    #-- Hide a given letter (for the blind-spot experiment).
    if State_At(board, position) != GIVEN:
        raise ValueError("only a given letter can be hidden")
    board.states[position] = BLANK
    board.values[position] = UNKNOWN


def Insert_Blank(
        board: Canvas,
        before: int
        ) -> None:
    #-- Puts a new hole just before position `before`. The canvas grows.
    if before > Length(board):
        raise ValueError("position outside the canvas")
    board.states.insert(before, BLANK)
    board.values.insert(before, UNKNOWN)
