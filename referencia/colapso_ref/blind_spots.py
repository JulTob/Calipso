"""Espejo de Colapso.Blind_Spots: el experimento de los puntos ciegos.

Se coge texto real, se tapan letras al azar y se pide al modelo que las
rellene. Como conocemos la respuesta, podemos contar aciertos.

Con el cerebro de conteo esto es un EXAMEN. Con una red neuronal, este
mismo juego será el ENTRENAMIENTO: tapar, apostar, destapar y corregir.
"""

from . import canvases
from . import distributions
from . import oracles
from . import random_sources
from . import templates


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


class Exam_Result:

    def __init__(self):
        self.hidden = 0
        self.hits = 0
        self.surprise_sum = 0.0


def Mean_Surprise(
        result: Exam_Result
        ) -> float:
    if result.hidden == 0:
        return 0.0
    return result.surprise_sum / float(result.hidden)


def Examine(
        model: oracles.Oracle,
        text: list,
        dice: random_sources.Generator,
        pieces: int,
        piece_length: int,
        rate: float
        ) -> Exam_Result:
    #-- El mismo examen para cualquier cerebro: tapar letras al azar en trozos de
    #-- texto y preguntar por cada letra tapada, SIN rellenar las demás.
    #-- Mide dos cosas: cuántas acierta y cuánto le sorprende la letra real.
    result = Exam_Result()
    room = len(text) - piece_length
    for _ in range(0, pieces):
        start = random_sources.Draw_Index(dice, room)
        original = templates.From_Text(text, start, piece_length)
        board = canvases.Copy(original)
        Hide_At_Random(board, rate, dice)
        for position in range(0, piece_length):
            if canvases.Is_Blank(board, position):
                belief = model.Opinion(board, position)
                actual = canvases.Symbol_At(original, position)
                result.hidden = result.hidden + 1
                result.surprise_sum = result.surprise_sum + distributions.Surprise_Of(belief, actual)
                if distributions.Most_Likely(belief) == actual:
                    result.hits = result.hits + 1
    return result
