"""Espejo de Colapso.Canvases: el lienzo donde se escribe el texto.

Un lienzo es una fila de celdas. Cada celda está en uno de tres estados:

  BLANK   : hueco. Todavía puede ser cualquier letra ("superposición").
  GIVEN   : letra dada por la persona. Es evidencia fija: no se toca nunca.
  GUESSED : letra decidida por el modelo. Se puede reabrir y volver a decidir.

Nota de espejo: aquí las posiciones empiezan en 0; en Ada empiezan en 1.
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
    #-- En Ada esto es una simple asignación: `Candidate := Board;`
    duplicate = Canvas()
    duplicate.states = list(board.states)
    duplicate.values = list(board.values)
    return duplicate


def Assign(
        target: Canvas,
        source: Canvas
        ) -> None:
    #-- En Ada esto es `Board := Candidate;`
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
        raise ValueError("un hueco no tiene letra")
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
    #-- Colapsar una celda: el hueco pasa a tener una letra decidida.
    if not Is_Blank(board, position):
        raise ValueError("solo se puede colapsar un hueco")
    board.states[position] = GUESSED
    board.values[position] = value


def Erase(
        board: Canvas,
        position: int
        ) -> None:
    #-- Reabrir una celda decidida por el modelo. Las dadas no se pueden borrar.
    if State_At(board, position) != GUESSED:
        raise ValueError("solo se puede reabrir una letra decidida por el modelo")
    board.states[position] = BLANK
    board.values[position] = UNKNOWN


def Hide(
        board: Canvas,
        position: int
        ) -> None:
    #-- Tapar una letra dada (para el experimento de los puntos ciegos).
    if State_At(board, position) != GIVEN:
        raise ValueError("solo se puede tapar una letra dada")
    board.states[position] = BLANK
    board.values[position] = UNKNOWN


def Insert_Blank(
        board: Canvas,
        before: int
        ) -> None:
    #-- Mete un hueco nuevo justo antes de la posición `before`. El lienzo crece.
    if before > Length(board):
        raise ValueError("posición fuera del lienzo")
    board.states.insert(before, BLANK)
    board.values.insert(before, UNKNOWN)
