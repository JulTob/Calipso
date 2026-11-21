"""Espejo de Colapso.Repairing: encontrar lo que chirría y arreglarlo.

Después de colapsar, cada letra se puede examinar: "si te tapo, ¿tus vecinas
te habrían adivinado?". Si la respuesta es "ni de lejos", esa letra sorprende:
ahí el texto no encaja.

  Sorpresa : cuánto extraña una letra a sus vecinas (en nats).
  Tensión  : suma de la sorpresa que pasa de lo tolerable, en la zona
             que el modelo ha tocado. Tensión 0 = "todo encaja".

Relajar el lienzo = repetir: buscar la letra que más sorprende, reabrir su
entorno y volver a colapsar. Si con el mismo sitio no mejora, se prueba a
ENSANCHAR: meter celdas nuevas ahí. Así el texto crece solo donde hace falta.
"""

from . import canvases
from . import collapsing
from . import distributions
from . import oracles
from . import random_sources


class Settings:

    def __init__(self):
        self.tolerance = 4.0
        #-- Sorpresa tolerable por letra, en nats. 4 nats = "pasa 1 de cada 55 veces".
        self.max_rounds = 40
        self.radius = 4
        #-- Al reabrir, cuántas celdas a cada lado del foco se vuelven huecos.
        self.extra_cells = 3
        #-- Al ensanchar, cuántas celdas nuevas se meten.
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
    #-- ¿Hay alguna letra decidida por el modelo al alcance de esta celda?
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
    #-- La celda medida que más sorprende. -1 si no hay ninguna (en Ada: 0).
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
    #-- La letra decidida por el modelo más cercana. A igual distancia, la de la izquierda.
    for distance in range(0, canvases.Length(board)):
        left = position - distance
        right = position + distance
        if left >= 0 and canvases.State_At(board, left) == canvases.GUESSED:
            return left
        if right < canvases.Length(board) and canvases.State_At(board, right) == canvases.GUESSED:
            return right
    raise ValueError("no hay letras decididas por el modelo")


def Reopen_Around(
        board: canvases.Canvas,
        focus: int,
        radius: int
        ) -> None:
    #-- Vuelve a dejar como huecos las letras del modelo cercanas al foco. Las dadas no se tocan.
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
    #-- Prueba un arreglo sobre una copia. Si baja la tensión, se queda; si no, se tira.
    #-- Devuelve la tensión con la que queda el lienzo.
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
        #-- Primer intento: mismo sitio, otras letras.
        if current < before:
            report.reopenings = report.reopenings + 1
        elif May_Grow(board, options):
            current = Attempt_Repair(board, model, dice, options, focus, options.extra_cells, current)
            #-- Segundo intento: más sitio.
            if current < before:
                report.widenings = report.widenings + 1
    report.final_tension = current
    return report
