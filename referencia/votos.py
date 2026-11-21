"""Espejo de apps/colapso_votos.adb: entrenar un cerebro con puntos ciegos.

Uso:
    python3 referencia/votos.py CORPUS [LECCIONES]

Aprende del primer 90 % del corpus y examina con el último 10 %.
Compara tres cerebros con el mismo examen:

    conteo              el de la etapa 1, que solo cuenta
    votos sin entrenar  el que aprende, antes de aprender nada
    votos entrenado     el mismo, después de jugar a los puntos ciegos
"""

import sys

from colapso_ref import alphabets
from colapso_ref import blind_spots
from colapso_ref import counting_oracles
from colapso_ref import oracles
from colapso_ref import random_sources
from colapso_ref import texts
from colapso_ref import voting_oracles

EXAM_PIECES = 40
EXAM_PIECE_LENGTH = 64
EXAM_SEED = 505
TRAINING_SEED = 77

RATE_CASES = [
    (0.15, 15),
    (0.50, 50),
    (0.85, 85),
    ]


def Show_Exam(
        name: str,
        model: oracles.Oracle,
        exam: list,
        rate: float,
        percent: int
        ) -> None:
    dice = random_sources.Seeded(EXAM_SEED)
    #-- Misma semilla para todos: cada cerebro recibe los mismos trozos y los mismos huecos.
    result = blind_spots.Examine(model, exam, dice, EXAM_PIECES, EXAM_PIECE_LENGTH, rate)
    share = 100.0 * float(result.hits) / float(result.hidden)
    surprise = blind_spots.Mean_Surprise(result)
    print(f"  tapado {percent} %  {name}: {share:5.1f} %   {surprise:.3f} nats   ({result.hidden} letras)")


def Run(
        corpus_name: str,
        lessons: int
        ) -> None:
    letters = alphabets.Alphabet()
    texts.Learn_Alphabet(corpus_name, letters)
    corpus = texts.Read_Symbols(corpus_name, letters)
    cut = (len(corpus) * 9) // 10
    study = texts.Part(corpus, 0, cut - 1)
    exam = texts.Part(corpus, cut, len(corpus) - 1)
    if len(exam) <= EXAM_PIECE_LENGTH:
        print("Error: el corpus es demasiado corto para este experimento.")
        return
    size = alphabets.Size(letters)
    print(f"Corpus: {len(corpus)} letras. Aprende de {len(study)}, examina con {len(exam)}.")

    counting = counting_oracles.Counting_Oracle()
    counting_oracles.Train(counting, study, size)

    untrained = voting_oracles.Voting_Oracle()
    voting_oracles.Prepare(untrained, size)

    trained = voting_oracles.Voting_Oracle()
    voting_oracles.Prepare(trained, size)
    plan = voting_oracles.Lesson_Plan()
    plan.lessons = lessons
    dice = random_sources.Seeded(TRAINING_SEED)
    print(f"Entrenando votos: {plan.lessons} lecciones, alcance {trained.reach}.")
    final_surprise = voting_oracles.Train(trained, study, dice, plan)
    print(f"Sorpresa media al final del entrenamiento: {final_surprise:.3f} nats")

    print("Examen de puntos ciegos (acierto y sorpresa media por letra tapada):")
    for rate, percent in RATE_CASES:
        Show_Exam("conteo            ", counting, exam, rate, percent)
        Show_Exam("votos sin entrenar", untrained, exam, rate, percent)
        Show_Exam("votos entrenado   ", trained, exam, rate, percent)


def Main() -> None:
    if len(sys.argv) < 2:
        print("Uso:")
        print("   colapso_votos CORPUS [LECCIONES]")
        sys.exit(1)
    lessons = voting_oracles.Lesson_Plan().lessons
    if len(sys.argv) >= 3:
        lessons = int(sys.argv[2])
    try:
        Run(sys.argv[1], lessons)
    except texts.Reading_Error as problem:
        print(f"Error: {problem}")
        sys.exit(1)


if __name__ == "__main__":
    Main()
