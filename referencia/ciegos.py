"""Espejo de apps/colapso_ciegos.adb: el experimento de los puntos ciegos.

Uso:
    python3 referencia/ciegos.py CORPUS [ENSAYOS]

Aprende del primer 90 % del corpus y examina con el último 10 %.
Con el mismo corpus y los mismos ensayos escribe lo mismo que el programa en Ada.
"""

import sys

from colapso_ref import alphabets
from colapso_ref import blind_spots
from colapso_ref import canvases
from colapso_ref import collapsing
from colapso_ref import counting_oracles
from colapso_ref import random_sources
from colapso_ref import templates
from colapso_ref import texts

DEFAULT_TRIALS = 60
PIECE_LENGTH = 300
BASE_SEED = 202

RATE_CASES = [
    (0.15, 15),
    (0.30, 30),
    (0.50, 50),
    (0.70, 70),
    ]

ORDERS = [
    collapsing.MOST_CERTAIN_FIRST,
    collapsing.LEFT_TO_RIGHT,
    collapsing.AT_RANDOM,
    ]


def Order_Name(
        order: int
        ) -> str:
    if order == collapsing.MOST_CERTAIN_FIRST:
        return "menos dudas primero"
    if order == collapsing.LEFT_TO_RIGHT:
        return "izquierda a derecha"
    return "orden al azar      "


def Percent_Image(
        part: int,
        whole: int
        ) -> str:
    if whole == 0:
        return "  n/d"
    share = 100.0 * float(part) / float(whole)
    return f"{share:5.1f}"


def Measure(
        model: counting_oracles.Counting_Oracle,
        exam: list,
        rate: float,
        order: int,
        trials: int
        ) -> blind_spots.Score:
    room = len(exam) - PIECE_LENGTH
    total = blind_spots.Score()
    for trial in range(0, trials):
        dice = random_sources.Seeded(BASE_SEED + trial)
        #-- Misma semilla por ensayo: todos los órdenes reciben el mismo trozo y los mismos huecos.
        start = random_sources.Draw_Index(dice, room)
        original = templates.From_Text(exam, start, PIECE_LENGTH)
        board = canvases.Copy(original)
        blind_spots.Hide_At_Random(board, rate, dice)
        collapsing.Collapse_All(board, model, dice, order, collapsing.ALWAYS_MOST_LIKELY)
        result = blind_spots.Scored(board, original)
        total.hidden = total.hidden + result.hidden
        total.recovered = total.recovered + result.recovered
    return total


def Run(
        corpus_name: str,
        trials: int
        ) -> None:
    letters = alphabets.Alphabet()
    texts.Learn_Alphabet(corpus_name, letters)
    corpus = texts.Read_Symbols(corpus_name, letters)
    cut = (len(corpus) * 9) // 10
    lessons = texts.Part(corpus, 0, cut - 1)
    exam = texts.Part(corpus, cut, len(corpus) - 1)
    if len(exam) <= PIECE_LENGTH:
        print("Error: el corpus es demasiado corto para este experimento.")
        return
    model = counting_oracles.Counting_Oracle()
    counting_oracles.Train(model, lessons, alphabets.Size(letters))
    print(f"Corpus: {len(corpus)} letras. Aprende de {len(lessons)}, examina con {len(exam)}.")
    print("Puntos ciegos al azar: % de letras tapadas que se recuperan")
    for rate, percent in RATE_CASES:
        for order in ORDERS:
            total = Measure(model, exam, rate, order, trials)
            print(f"  tapado {percent} %  {Order_Name(order)}: {Percent_Image(total.recovered, total.hidden)} %   ({total.hidden} letras)")


def Main() -> None:
    if len(sys.argv) < 2:
        print("Uso:")
        print("   colapso_ciegos CORPUS [ENSAYOS]")
        sys.exit(1)
    trials = DEFAULT_TRIALS
    if len(sys.argv) >= 3:
        trials = int(sys.argv[2])
    try:
        Run(sys.argv[1], trials)
    except texts.Reading_Error as problem:
        print(f"Error: {problem}")
        sys.exit(1)


if __name__ == "__main__":
    Main()
