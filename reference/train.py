"""Mirror of apps/calipso_train.adb: train a brain with blind spots.

Usage:
    python3 reference/train.py CORPUS [LESSONS]

Learns from the first 90 % of the corpus and examines with the last 10 %.
Compares three brains with the same exam:

    counting         the stage 1 brain, which only counts
    votes untrained  the brain that learns, before learning anything
    votes trained    the same brain, after playing the blind-spot game
"""

import sys

from calipso_ref import alphabets
from calipso_ref import blind_spots
from calipso_ref import counting_oracles
from calipso_ref import oracles
from calipso_ref import random_sources
from calipso_ref import texts
from calipso_ref import voting_oracles

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
    #-- Same seed for all: every brain gets the same pieces and the same holes.
    result = blind_spots.Examine(model, exam, dice, EXAM_PIECES, EXAM_PIECE_LENGTH, rate)
    share = 100.0 * float(result.hits) / float(result.hidden)
    surprise = blind_spots.Mean_Surprise(result)
    print(f"  hidden {percent} %  {name}: {share:5.1f} %   {surprise:.3f} nats   ({result.hidden} letters)")


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
        print("Error: the corpus is too short for this experiment.")
        return
    size = alphabets.Size(letters)
    print(f"Corpus: {len(corpus)} letters. Learns from {len(study)}, examines with {len(exam)}.")

    counting = counting_oracles.Counting_Oracle()
    counting_oracles.Train(counting, study, size)

    untrained = voting_oracles.Voting_Oracle()
    voting_oracles.Prepare(untrained, size)

    trained = voting_oracles.Voting_Oracle()
    voting_oracles.Prepare(trained, size)
    plan = voting_oracles.Lesson_Plan()
    plan.lessons = lessons
    dice = random_sources.Seeded(TRAINING_SEED)
    print(f"Training votes: {plan.lessons} lessons, reach {trained.reach}.")
    final_surprise = voting_oracles.Train(trained, study, dice, plan)
    print(f"Mean surprise at the end of training: {final_surprise:.3f} nats")

    print("Blind-spot exam (hits and mean surprise per hidden letter):")
    for rate, percent in RATE_CASES:
        Show_Exam("counting       ", counting, exam, rate, percent)
        Show_Exam("votes untrained", untrained, exam, rate, percent)
        Show_Exam("votes trained  ", trained, exam, rate, percent)


def Main() -> None:
    if len(sys.argv) < 2:
        print("Usage:")
        print("   calipso_train CORPUS [LESSONS]")
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
