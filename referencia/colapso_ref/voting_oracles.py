"""Espejo de Colapso.Voting_Oracles: un cerebro que aprende.

Idea: cada vecina conocida VOTA. Un voto es una fila de puntos, a favor o en
contra de cada letra candidata. Hay una fila de puntos distinta para cada
pareja (distancia al hueco, letra que hay ahí):

    "tengo una 'q' justo a tu izquierda"  ->  muchos puntos para la 'u'

Para opinar se suman los votos de todas las vecinas conocidas (los huecos no
votan) y los puntos se convierten en probabilidades.

Al principio todos los puntos valen 0: el cerebro no sabe nada. Aprende
jugando a los puntos ciegos: se le tapa una letra, opina, se le enseña la
letra real, y cada vecina que votó corrige un poco sus puntos.
"""

from . import blind_spots
from . import canvases
from . import distributions
from . import oracles
from . import random_sources
from . import templates

DEFAULT_REACH = 12
#-- Hasta cuántas celdas de distancia vota una vecina, a cada lado.


class Lesson_Plan:

    def __init__(self):
        self.lessons = 4000
        #-- Cuántos trozos de texto se estudian.
        self.piece_length = 64
        self.learning_rate = 0.5
        #-- Qué parte del error se corrige en cada letra: 0 = nada, 1 = todo de golpe.


class Voting_Oracle(oracles.Oracle):

    def __init__(self):
        self.letter_count = 1
        self.reach = DEFAULT_REACH
        self.bias = [0.0, 0.0]
        #-- bias[candidata]: puntos de partida de cada letra, sin mirar a nadie.
        self.votes = [0.0]
        #-- Todos los votos en una sola fila larga. Ver Slot_Of.

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
    #-- Sitio en la fila larga del punto (distancia, letra vecina, letra candidata).
    #-- Nota de espejo: en Ada la fila empieza en 1, por eso allí se suma 1 al final.
    side = offset + model.reach
    row = side * model.letter_count + (neighbour - 1)
    return row * model.letter_count + (candidate - 1)


def Prepare(
        model: Voting_Oracle,
        letter_count: int,
        reach: int = DEFAULT_REACH
        ) -> None:
    #-- Deja el cerebro en blanco: todos los puntos a 0.
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
    #-- ¿Hay una vecina con letra a esa distancia?
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
    #-- Suma de votos para cada letra candidata. scores[candidata]; la posición 0 no se usa.
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
    #-- Una lección mínima: opinar sobre una celda tapada, mirar la letra real y corregir.
    #-- Devuelve la sorpresa que causó la letra real ANTES de corregir.
    belief = model.Opinion(board, position)
    surprise = distributions.Surprise_Of(belief, actual)
    voters = Voter_Count(board, position, model.reach)
    step = learning_rate / float(voters + 1)
    #-- La corrección se reparte a partes iguales entre las vecinas que votaron y el punto de partida.
    errors = [0.0] * (model.letter_count + 1)
    for candidate in range(1, model.letter_count + 1):
        errors[candidate] = distributions.Probability_Of(belief, candidate)
        #-- A cada letra se le quita lo que se apostó por ella...
    errors[actual] = errors[actual] - 1.0
    #-- ...y a la letra real se le da lo que le faltaba para llegar a 1.
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
    #-- Entrenar = jugar muchas veces a los puntos ciegos.
    #-- Devuelve la sorpresa media durante la última décima parte de las lecciones.
    room = len(text) - plan.piece_length
    last_stretch = plan.lessons - plan.lessons // 10
    surprise_sum = 0.0
    cells = 0
    for lesson in range(0, plan.lessons):
        start = random_sources.Draw_Index(dice, room)
        original = templates.From_Text(text, start, plan.piece_length)
        board = canvases.Copy(original)
        rate = random_sources.Draw_Unit(dice)
        #-- Cada lección tapa una cantidad distinta: a veces casi nada, a veces casi todo.
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
