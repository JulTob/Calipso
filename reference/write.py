"""A program that writes, by either method. It mirrors apps/calipso_write.adb.

Usage:
   python3 reference/write.py CORPUS [method=flat|spell|pick] [words=N] [texts=N] [seed=N]

It studies CORPUS and then writes.

   method=flat   one level: letters only (the method Calipso started with)
   method=spell  two levels: kinds of word, then the letter brain spells each word in its box
   method=pick   two levels: kinds of word, then a word seen in that kind is taken
   words=N       about how many words each text has (12 if not said)
   texts=N       how many texts to write (3 if not said)
   seed=N        where the dice start (1 if not said)

A line feed inside a text is shown as " / ", so that every text stays on one line.
"""

import sys

from calipso_ref import alphabets
from calipso_ref import counting_oracles
from calipso_ref import pyramids
from calipso_ref import random_sources
from calipso_ref import texts
from calipso_ref import writers

DEFAULT_WORDS = 12
DEFAULT_TEXTS = 3
DEFAULT_SEED = 1
MOST_DIGITS = 9
LINE_FEED = "\n"
SHOWN_BREAK = " / "


class Bad_Argument(Exception):
    pass


class Choices:
    #-- What the command line asked for.

    def __init__(self):
        self.method = "spell"
        self.words = DEFAULT_WORDS
        self.texts = DEFAULT_TEXTS
        self.seed = DEFAULT_SEED


def Whole_Number(
        word: str,
        least: int
        ) -> int:
    if word == "" or len(word) > MOST_DIGITS or not all("0" <= char <= "9" for char in word):
        raise Bad_Argument("a whole number was expected. Found: " + word)
    value = int(word)
    if value < least:
        raise Bad_Argument(f"the number must be {least} or more. Found: " + word)
    return value


def Take_Option(
        wanted: Choices,
        word: str
        ) -> None:
    #-- One option, written name=value.
    equal = word.find("=")
    if equal < 0:
        raise Bad_Argument("options are written name=value, for example words=20. Found: " + word)
    name = word[:equal]
    value = word[equal + 1:]
    if name == "method":
        if value not in ("flat", "spell", "pick"):
            raise Bad_Argument("the method is flat, spell or pick. Found: " + value)
        wanted.method = value
    elif name == "words":
        wanted.words = Whole_Number(value, 1)
    elif name == "texts":
        wanted.texts = Whole_Number(value, 1)
    elif name == "seed":
        wanted.seed = Whole_Number(value, 0)
    else:
        raise Bad_Argument("there is no option called " + name)


def Shown(
        text: str
        ) -> str:
    return text.replace(LINE_FEED, SHOWN_BREAK)


def Write_Texts(
        author: writers.Writer,
        wanted: Choices
        ) -> None:
    for number in range(1, wanted.texts + 1):
        dice = random_sources.Seeded(wanted.seed + number - 1)
        print(f"{number}: " + Shown(author.Write(dice, wanted.words)))


def Run(
        corpus_name: str,
        wanted: Choices
        ) -> None:
    letters = alphabets.Alphabet()
    texts.Learn_Alphabet(corpus_name, letters)
    speller = counting_oracles.Counting_Oracle()
    counting_oracles.Train(speller, texts.Read_Symbols(corpus_name, letters), alphabets.Size(letters))
    print(f"Method: {wanted.method}. About {wanted.words} words in each text.")
    if wanted.method == "flat":
        Write_Texts(writers.Flat_Writer(speller, letters), wanted)
        return
    plan = pyramids.Pyramid()
    pyramids.Study(plan, texts.Whole_Text(corpus_name))
    passing = pyramids.PICK if wanted.method == "pick" else pyramids.SPELL
    Write_Texts(writers.Pyramid_Writer(plan, speller, letters, passing), wanted)


def Show_Usage() -> None:
    print("Usage:")
    print("   calipso_write CORPUS [method=flat|spell|pick] [words=N] [texts=N] [seed=N]")


def Main() -> None:
    arguments = sys.argv[1:]
    if len(arguments) < 1:
        Show_Usage()
        sys.exit(1)
    wanted = Choices()
    try:
        for word in arguments[1:]:
            Take_Option(wanted, word)
        Run(arguments[0], wanted)
    except Bad_Argument as problem:
        print("Error: " + str(problem))
        sys.exit(1)
    except texts.Reading_Error as problem:
        print("Error: " + str(problem))
        sys.exit(1)


Main()
