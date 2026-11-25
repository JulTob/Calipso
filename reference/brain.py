"""Mirror of apps/calipso_brain.adb: brains that are kept between runs.

Usage:
    python3 reference/brain.py study BRAIN_FILE CORPUS [LESSONS] [RECIPE]
    python3 reference/brain.py compare CORPUS BRAIN_FILE [BRAIN_FILE ...]

study   : loads the brain from BRAIN_FILE, or makes a new one from RECIPE if
          the file does not exist. It studies LESSONS more lessons, takes the
          exam, and saves the brain back. Run it again and it carries on.
compare : gives the same exam to several saved brains.

A recipe is a list of neuron names joined by "+":
    bias  position  presence  harmonic  decay  counting  memory
"""

import os
import sys

from calipso_ref import alphabets
from calipso_ref import blind_spots
from calipso_ref import brains
from calipso_ref import neuron_kinds
from calipso_ref import random_sources
from calipso_ref import records
from calipso_ref import sources
from calipso_ref import texts

DEFAULT_LESSONS = 2000
DEFAULT_RECIPE = "bias+position"
PIECE_LENGTH = 64
EXAM_PIECES = 40
EXAM_SEED = 505
STUDY_SEED = 77
HIDING_SEED = 1077

RATE_CASES = [
    (0.15, 15),
    (0.50, 50),
    (0.85, 85),
    ]


class Bad_Argument(Exception):
    pass


def Percent_Image(
        part: int,
        whole: int
        ) -> str:
    if whole == 0:
        return "  n/a"
    share = 100.0 * float(part) / float(whole)
    return f"{share:5.1f}"


def Show_Exam(
        brain: brains.Brain,
        exam: list
        ) -> None:
    for rate, percent in RATE_CASES:
        dice = random_sources.Seeded(EXAM_SEED)
        #-- Same seed for all: every brain gets the same pieces and the same holes.
        result = blind_spots.Examine(brain, exam, dice, EXAM_PIECES, PIECE_LENGTH, rate)
        surprise = blind_spots.Mean_Surprise(result)
        print(f"  hidden {percent} %: {Percent_Image(result.hits, result.hidden)} %   {surprise:.3f} nats")


def Split(
        corpus: list
        ) -> tuple:
    #-- The first 90 % to study from, the last 10 % to examine with.
    cut = (len(corpus) * 9) // 10
    study = texts.Part(corpus, 0, cut - 1)
    exam = texts.Part(corpus, cut, len(corpus) - 1)
    return study, exam


def Run_Study(
        brain_name: str,
        corpus_name: str,
        lessons: int,
        recipe: str
        ) -> None:
    brain = brains.Brain()
    if os.path.exists(brain_name):
        brains.Load(brain, brain_name)
        print(f"Brain: {brains.Recipe_Of(brain)} (loaded, {brain.lessons} lessons so far)")
    else:
        letters = alphabets.Alphabet()
        texts.Learn_Alphabet(corpus_name, letters)
        brains.Prepare(brain, letters)
        brains.Add_Recipe(brain, recipe)
        print(f"Brain: {brains.Recipe_Of(brain)} (new)")
    corpus = texts.Read_Symbols(corpus_name, brain.letters)
    #-- The corpus is read with the brain's own alphabet, so a loaded brain keeps its letters.
    study, exam = Split(corpus)
    if len(exam) <= PIECE_LENGTH:
        print("Error: the corpus is too short for this experiment.")
        return
    print(f"Corpus: {len(corpus)} letters. Studies from {len(study)}, examines with {len(exam)}.")
    source = sources.Memory_Source()
    sources.Open_Memory(source, study, PIECE_LENGTH, STUDY_SEED + brain.lessons)
    dice = random_sources.Seeded(HIDING_SEED + brain.lessons)
    #-- The seeds move with the lessons already studied: a second run sees new pieces.
    result = brains.Study(brain, source, dice, lessons)
    surprise = blind_spots.Mean_Surprise(result)
    print(f"Studied {lessons} lessons. While studying: right {Percent_Image(result.hits, result.hidden)} %, mean surprise {surprise:.3f} nats ({result.hidden} letters)")
    print(f"Lessons so far: {brain.lessons}")
    print("Exam (hidden letters right, mean surprise):")
    Show_Exam(brain, exam)
    brains.Save(brain, brain_name)
    print(f"Saved to {brain_name}")


def Run_Compare(
        corpus_name: str,
        brain_names: list
        ) -> None:
    for brain_name in brain_names:
        brain = brains.Brain()
        brains.Load(brain, brain_name)
        corpus = texts.Read_Symbols(corpus_name, brain.letters)
        study, exam = Split(corpus)
        if len(exam) <= PIECE_LENGTH:
            print("Error: the corpus is too short for this experiment.")
            return
        print(f"{brain_name}: {brains.Recipe_Of(brain)}, {brain.lessons} lessons")
        Show_Exam(brain, exam)


def Run_Copy(
        from_name: str,
        to_name: str
        ) -> None:
    #-- Loads a brain and saves it under another name. The ending of the new
    #-- name decides the form: .zmb is packed, anything else is text that is also Ada.
    brain = brains.Brain()
    brains.Load(brain, from_name)
    brains.Save(brain, to_name)
    print(f"{from_name}: {brains.Recipe_Of(brain)}, {brain.lessons} lessons")
    print(f"Copied: {os.path.getsize(from_name)} bytes -> {os.path.getsize(to_name)} bytes in {to_name}")


def Whole_Number(
        word: str
        ) -> int:
    try:
        value = int(word)
    except ValueError:
        raise Bad_Argument("the number of lessons must be a whole number, 0 or greater")
    if value < 0:
        raise Bad_Argument("the number of lessons must be a whole number, 0 or greater")
    return value


def Show_Usage() -> None:
    print("Usage:")
    print("   calipso_brain study BRAIN_FILE CORPUS [LESSONS] [RECIPE]")
    print("   calipso_brain compare CORPUS BRAIN_FILE [BRAIN_FILE ...]")
    print("   calipso_brain copy FROM_FILE TO_FILE")


def Main() -> None:
    arguments = sys.argv[1:]
    try:
        if len(arguments) >= 3 and arguments[0] == "study":
            lessons = DEFAULT_LESSONS
            recipe = DEFAULT_RECIPE
            if len(arguments) >= 4:
                lessons = Whole_Number(arguments[3])
            if len(arguments) >= 5:
                recipe = arguments[4]
            Run_Study(arguments[1], arguments[2], lessons, recipe)
        elif len(arguments) >= 3 and arguments[0] == "compare":
            Run_Compare(arguments[1], arguments[2:])
        elif len(arguments) == 3 and arguments[0] == "copy":
            Run_Copy(arguments[1], arguments[2])
        else:
            Show_Usage()
            sys.exit(1)
    except (texts.Reading_Error, records.Record_Error, neuron_kinds.Recipe_Error, Bad_Argument) as problem:
        print(f"Error: {problem}")
        sys.exit(1)


if __name__ == "__main__":
    Main()
