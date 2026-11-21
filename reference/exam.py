"""Mirror of apps/calipso_exam.adb: the blind-spot exam.

Usage:
    python3 reference/exam.py CORPUS [TRIALS]

Learns from the first 90 % of the corpus and examines with the last 10 %.
With the same corpus and the same trials it writes the same as the Ada program.
"""

import sys

from calipso_ref import alphabets
from calipso_ref import blind_spots
from calipso_ref import canvases
from calipso_ref import collapsing
from calipso_ref import counting_oracles
from calipso_ref import random_sources
from calipso_ref import templates
from calipso_ref import texts

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
        return "most certain first"
    if order == collapsing.LEFT_TO_RIGHT:
        return "left to right     "
    return "random order      "


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
        #-- Same seed per trial: every order gets the same piece and the same holes.
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
        print("Error: the corpus is too short for this experiment.")
        return
    model = counting_oracles.Counting_Oracle()
    counting_oracles.Train(model, lessons, alphabets.Size(letters))
    print(f"Corpus: {len(corpus)} letters. Learns from {len(lessons)}, examines with {len(exam)}.")
    print("Random blind spots: % of hidden letters recovered")
    for rate, percent in RATE_CASES:
        for order in ORDERS:
            total = Measure(model, exam, rate, order, trials)
            print(f"  hidden {percent} %  {Order_Name(order)}: {Percent_Image(total.recovered, total.hidden)} %   ({total.hidden} letters)")


def Main() -> None:
    if len(sys.argv) < 2:
        print("Usage:")
        print("   calipso_exam CORPUS [TRIALS]")
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
