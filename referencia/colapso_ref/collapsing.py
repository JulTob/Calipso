"""Espejo de Colapso.Collapsing: el motor de colapso.

Bucle (el mismo del algoritmo "Wave Function Collapse"):

  1. Observar : buscar el hueco sobre el que hay MENOS dudas.
  2. Colapsar : decidir su letra tirando un dado cargado con la opinión.
  3. Propagar : las opiniones de sus vecinas han cambiado; hay que recalcularlas.

y repetir hasta que no queden huecos.
"""

from . import canvases
from . import distributions
from . import oracles
from . import random_sources

MOST_CERTAIN_FIRST = 0
LEFT_TO_RIGHT = 1
AT_RANDOM = 2
#-- Orden de visita de los huecos. El primero es el colapso; los otros dos están para comparar.

BY_CHANCE = 0
ALWAYS_MOST_LIKELY = 1
#-- Cómo se decide la letra: sorteando según la opinión, o cogiendo siempre la más probable.


class Uncertainty_Note:

    def __init__(self):
        self.is_fresh = False
        self.entropy = 0.0


def Fresh_Notes(
        length: int
        ) -> list:
    notes = []
    for _ in range(0, length):
        notes.append(Uncertainty_Note())
    return notes


def Refresh(
        notes: list,
        board: canvases.Canvas,
        model: oracles.Oracle
        ) -> None:
    #-- Recalcula la duda de los huecos cuya nota está caducada.
    for position in range(0, canvases.Length(board)):
        if canvases.Is_Blank(board, position) and not notes[position].is_fresh:
            belief = model.Opinion(board, position)
            notes[position].entropy = distributions.Entropy(belief)
            notes[position].is_fresh = True


def Most_Certain_Blank(
        notes: list,
        board: canvases.Canvas
        ) -> int:
    #-- El hueco con menos dudas. En caso de empate, el primero.
    best = -1
    for position in range(0, canvases.Length(board)):
        if canvases.Is_Blank(board, position):
            if best < 0:
                best = position
            elif notes[position].entropy < notes[best].entropy:
                best = position
    return best


def First_Blank(
        board: canvases.Canvas
        ) -> int:
    for position in range(0, canvases.Length(board)):
        if canvases.Is_Blank(board, position):
            return position
    raise ValueError("no quedan huecos")


def Random_Blank(
        board: canvases.Canvas,
        dice: random_sources.Generator
        ) -> int:
    blank_count = canvases.Blank_Count(board)
    skip = random_sources.Draw_Index(dice, blank_count)
    for position in range(0, canvases.Length(board)):
        if canvases.Is_Blank(board, position):
            if skip == 0:
                return position
            skip = skip - 1
    raise ValueError("no quedan huecos")


def Next_Target(
        board: canvases.Canvas,
        model: oracles.Oracle,
        dice: random_sources.Generator,
        order: int,
        notes: list
        ) -> int:
    if order == MOST_CERTAIN_FIRST:
        Refresh(notes, board, model)
        return Most_Certain_Blank(notes, board)
    if order == LEFT_TO_RIGHT:
        return First_Blank(board)
    return Random_Blank(board, dice)


def Collapse_Cell(
        board: canvases.Canvas,
        model: oracles.Oracle,
        dice: random_sources.Generator,
        rule: int,
        position: int
        ) -> None:
    belief = model.Opinion(board, position)
    if rule == ALWAYS_MOST_LIKELY:
        chosen = distributions.Most_Likely(belief)
    else:
        unit = random_sources.Draw_Unit(dice)
        chosen = distributions.Sampled(belief, unit)
    canvases.Guess(board, position, chosen)


def Mark_Stale_Around(
        notes: list,
        position: int,
        reach: int
        ) -> None:
    #-- Propagar: todo lo que esté al alcance de la celda colapsada debe recalcularse.
    first = max(0, position - reach)
    last = min(len(notes) - 1, position + reach)
    for neighbour in range(first, last + 1):
        notes[neighbour].is_fresh = False


def Collapse_All(
        board: canvases.Canvas,
        model: oracles.Oracle,
        dice: random_sources.Generator,
        order: int = MOST_CERTAIN_FIRST,
        rule: int = BY_CHANCE,
        observer=None
        ) -> None:
    notes = Fresh_Notes(canvases.Length(board))
    while canvases.Blank_Count(board) > 0:
        target = Next_Target(board, model, dice, order, notes)
        Collapse_Cell(board, model, dice, rule, target)
        Mark_Stale_Around(notes, target, model.Reach())
        if observer is not None:
            observer(board, target)
