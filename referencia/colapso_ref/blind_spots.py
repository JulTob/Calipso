"""Espejo de Colapso.Blind_Spots: el experimento de los puntos ciegos.

Se coge texto real, se tapan letras al azar y se pide al modelo que las
rellene. Como conocemos la respuesta, podemos contar aciertos.

Con el cerebro de conteo esto es un EXAMEN. Con una red neuronal, este
mismo juego será el ENTRENAMIENTO: tapar, apostar, destapar y corregir.
"""

from . import canvases
from . import random_sources


class Score:

    def __init__(self):
        self.hidden = 0
        self.recovered = 0


def Hide_At_Random(
        board: canvases.Canvas,
        rate: float,
        dice: random_sources.Generator
        ) -> None:
    #-- Cada letra dada se tapa con probabilidad `rate`.
    for position in range(0, canvases.Length(board)):
        if canvases.State_At(board, position) == canvases.GIVEN:
            unit = random_sources.Draw_Unit(dice)
            if unit < rate:
                canvases.Hide(board, position)


def Scored(
        filled: canvases.Canvas,
        original: canvases.Canvas
        ) -> Score:
    #-- Compara el lienzo rellenado con el original, celda a celda.
    score = Score()
    for position in range(0, canvases.Length(filled)):
        if canvases.State_At(filled, position) == canvases.GUESSED:
            score.hidden = score.hidden + 1
            if canvases.Symbol_At(filled, position) == canvases.Symbol_At(original, position):
                score.recovered = score.recovered + 1
    return score
