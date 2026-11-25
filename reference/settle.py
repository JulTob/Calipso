"""A program that changes a text at fixed points and lets the rest settle.
It mirrors apps/calipso_settle.adb.

Usage:
   python3 reference/settle.py CORPUS TEXT [pin=PLACE:LETTERS] [wrong=PLACE] [sure=X] [signed=X] [passes=N]

It studies CORPUS, writes TEXT on a canvas, and reads it again and again until
nothing changes. Places count letters from 1.

   pin=PLACE:LETTERS  these letters are written from PLACE on, and they are certain
   wrong=PLACE        the letter at PLACE is surely wrong: it must change
   sure=X             how sure every other letter is, as a chance from 0 to 1
   signed=X           the same dial on the scale from -1 (surely wrong) through
                      0 (no idea) to 1 (surely right). 0.99 if neither is said
   passes=N           the most readings (8 if not said)
"""

import sys

from calipso_ref import alphabets
from calipso_ref import anchored_oracles
from calipso_ref import canvases
from calipso_ref import certainties
from calipso_ref import counting_oracles
from calipso_ref import settling
from calipso_ref import texts

DEFAULT_SIGNED = 0.99
MOST_DIGITS = 9


class Bad_Argument(Exception):
    pass


class Pin:

    def __init__(
            self,
            place: int,
            letters: str
            ):
        self.place = place
        self.letters = letters


class Choices:
    #-- What the command line asked for.

    def __init__(self):
        self.pins = []
        self.wrongs = []
        self.has_sure = False
        self.sure = 1.0
        self.signed = DEFAULT_SIGNED
        self.passes = settling.DEFAULT_PASSES


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


def Real_Number(
        word: str,
        lowest: float,
        highest: float
        ) -> float:
    try:
        value = float(word)
    except ValueError:
        raise Bad_Argument("a number was expected, like 0.9. Found: " + word)
    if not (lowest <= value <= highest):
        raise Bad_Argument("the number is outside its scale. Found: " + word)
    return value


def Pin_Of(
        value: str
        ) -> Pin:
    colon = value.find(":")
    if colon < 0 or colon == len(value) - 1:
        raise Bad_Argument("a pin is written PLACE:LETTERS, for example pin=5:ga. Found: " + value)
    return Pin(Whole_Number(value[:colon], 1), value[colon + 1:])


def Take_Option(
        wanted: Choices,
        word: str
        ) -> None:
    #-- One option, written name=value.
    equal = word.find("=")
    if equal < 0:
        raise Bad_Argument("options are written name=value, for example signed=0.9. Found: " + word)
    name = word[:equal]
    value = word[equal + 1:]
    if name == "pin":
        wanted.pins.append(Pin_Of(value))
    elif name == "wrong":
        wanted.wrongs.append(Whole_Number(value, 1))
    elif name == "sure":
        wanted.sure = Real_Number(value, 0.0, 1.0)
        wanted.has_sure = True
    elif name == "signed":
        wanted.signed = Real_Number(value, -1.0, 1.0)
        wanted.has_sure = False
    elif name == "passes":
        wanted.passes = Whole_Number(value, 1)
    else:
        raise Bad_Argument("there is no option called " + name)


def Check_Place(
        place: int,
        last: int,
        length: int
        ) -> None:
    if last > length:
        raise Bad_Argument(f"place {place} is beyond the end of the text, which has {length} letters")


def Write_Pins(
        symbols: list,
        wanted: Choices,
        letters: alphabets.Alphabet
        ) -> None:
    #-- The pinned letters replace what the text had.
    for pin in wanted.pins:
        Check_Place(pin.place, pin.place + len(pin.letters) - 1, len(symbols))
        pinned = texts.Encoded(pin.letters, letters)
        for index in range(0, len(pinned)):
            symbols[pin.place - 1 + index] = pinned[index]


def Anchors_For(
        symbols: list,
        wanted: Choices,
        size: int
        ) -> list:
    #-- Every letter holds on as the dial says; pinned letters are certain; marked letters are surely wrong.
    rest = wanted.sure if wanted.has_sure else certainties.Certainty_Of(wanted.signed, size)
    anchors = settling.Even_Anchors(symbols, rest)
    for pin in wanted.pins:
        for index in range(0, len(pin.letters)):
            place = pin.place - 1 + index
            anchors[place] = anchored_oracles.Anchor_Of(symbols[place], 1.0)
    for place in wanted.wrongs:
        Check_Place(place, place, len(symbols))
        anchors[place - 1] = anchored_oracles.Anchor_Of(symbols[place - 1], 0.0)
    return anchors


def Text_On(
        board: canvases.Canvas,
        letters: alphabets.Alphabet
        ) -> str:
    symbols = []
    for position in range(0, canvases.Length(board)):
        symbols.append(canvases.Symbol_At(board, position))
    return texts.Decoded(symbols, letters)


def Run(
        corpus_name: str,
        text: str,
        wanted: Choices
        ) -> None:
    letters = alphabets.Alphabet()
    texts.Learn_Alphabet(corpus_name, letters)
    size = alphabets.Size(letters)
    speller = counting_oracles.Counting_Oracle()
    counting_oracles.Train(speller, texts.Read_Symbols(corpus_name, letters), size)
    symbols = texts.Encoded(text, letters)
    Write_Pins(symbols, wanted, letters)
    anchors = Anchors_For(symbols, wanted, size)
    board = settling.Written(symbols)
    print("Before: " + Text_On(board, letters))
    outcome = settling.Settle(board, speller, anchors, wanted.passes)
    print("After:  " + Text_On(board, letters))
    settled = "yes" if outcome.is_settled else "no"
    print(f"Readings: {outcome.passes}. Letters rewritten: {outcome.changes}. Settled: {settled}.")


def Show_Usage() -> None:
    print("Usage:")
    print("   calipso_settle CORPUS TEXT [pin=PLACE:LETTERS] [wrong=PLACE] [sure=X] [signed=X] [passes=N]")


def Main() -> None:
    arguments = sys.argv[1:]
    if len(arguments) < 2:
        Show_Usage()
        sys.exit(1)
    wanted = Choices()
    try:
        for word in arguments[2:]:
            Take_Option(wanted, word)
        Run(arguments[0], arguments[1], wanted)
    except Bad_Argument as problem:
        print("Error: " + str(problem))
        sys.exit(1)
    except texts.Reading_Error as problem:
        print("Error: " + str(problem))
        sys.exit(1)


Main()
