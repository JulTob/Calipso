"""Espejo de Colapso.Counting_Oracles: un cerebro que solo sabe contar.

Idea: para opinar sobre un hueco, miro una "ventana" de letras conocidas
a su alrededor y pregunto a la tabla:

    "De todas las veces que vi esta ventana en el corpus,
     ¿qué letra había en el sitio del hueco?"

Empiezo con una ventana vacía (solo la frecuencia de cada letra) y la voy
ensanchando una vecina cada vez, alternando izquierda y derecha. Cada
ventana más ancha corrige la opinión de la anterior.
"""

from . import canvases
from . import distributions
from . import fragment_counts
from . import oracles

DEFAULT_LONGEST = 7
#-- Ventana más ancha: el hueco más 6 vecinas.


class Counting_Oracle(oracles.Oracle):

    def __init__(self):
        self.letter_count = 1
        self.longest = DEFAULT_LONGEST
        self.table = fragment_counts.Count_Table()

    def Alphabet_Size(self) -> int:
        return self.letter_count

    def Reach(self) -> int:
        return self.longest - 1

    def Opinion(
            self,
            board: canvases.Canvas,
            position: int
            ) -> distributions.Distribution:
        left_known = Known_Run(board, position, -1, self.longest - 1)
        right_known = Known_Run(board, position, +1, self.longest - 1)
        left_used = 0
        right_used = 0
        belief = distributions.Uniform(self.letter_count)
        #-- Antes de mirar nada, todas las letras son igual de posibles.
        while True:
            clue = Evidence(self, board, position, left_used, right_used)
            if distributions.Total(clue) == 0.0:
                break
                #-- Esta ventana no se vio nunca: una más ancha tampoco. Paramos.
            belief = Updated(belief, clue)
            window_length = left_used + 1 + right_used
            if window_length >= self.longest:
                break
            can_left = left_used < left_known
            can_right = right_used < right_known
            if not can_left and not can_right:
                break
            if Should_Widen_Left(can_left, can_right, left_used, right_used):
                left_used = left_used + 1
            else:
                right_used = right_used + 1
        return belief


def Train(
        model: Counting_Oracle,
        text: list,
        letter_count: int,
        longest: int = DEFAULT_LONGEST
        ) -> None:
    #-- "Entrenar" este cerebro es solo contar fragmentos.
    model.letter_count = letter_count
    model.longest = longest
    model.table = fragment_counts.Count_Table()
    fragment_counts.Learn(model.table, text, longest)


def Known_Run(
        board: canvases.Canvas,
        position: int,
        direction: int,
        limit: int
        ) -> int:
    #-- Cuántas celdas seguidas con letra hay pegadas al hueco, hacia un lado (-1 izquierda, +1 derecha).
    run = 0
    while run < limit:
        neighbour = position + direction * (run + 1)
        if neighbour < 0:
            break
        if neighbour >= canvases.Length(board):
            break
        if canvases.Is_Blank(board, neighbour):
            break
        run = run + 1
    return run


def Should_Widen_Left(
        can_left: bool,
        can_right: bool,
        left_used: int,
        right_used: int
        ) -> bool:
    #-- Alternar lados; si solo se puede por uno, por ese.
    if not can_left:
        return False
    if not can_right:
        return True
    return left_used <= right_used


def Evidence(
        model: Counting_Oracle,
        board: canvases.Canvas,
        position: int,
        left_used: int,
        right_used: int
        ) -> distributions.Distribution:
    #-- Para cada letra candidata: cuántas veces se vio la ventana con esa letra en el hueco.
    left_part = []
    for offset in range(left_used, 0, -1):
        left_part.append(canvases.Symbol_At(board, position - offset))
    right_part = []
    for offset in range(1, right_used + 1):
        right_part.append(canvases.Symbol_At(board, position + offset))
    clue = distributions.Zero(model.letter_count)
    for candidate in range(1, model.letter_count + 1):
        window = bytes(left_part + [candidate] + right_part)
        seen = fragment_counts.Count_Of(model.table, window)
        distributions.Set_Weight(clue, candidate, float(seen))
    return clue


def Updated(
        belief: distributions.Distribution,
        clue: distributions.Distribution
        ) -> distributions.Distribution:
    #-- Mezcla la opinión anterior con la evidencia nueva.
    #-- La opinión anterior vale tantas "observaciones" como letras distintas
    #-- se vieron en esta ventana: si tras este contexto ha venido de todo,
    #-- me fío menos de él y más de lo que ya pensaba.
    prior_strength = float(distributions.Variety(clue))
    mixed = clue + prior_strength * belief
    return distributions.Normalized(mixed)
